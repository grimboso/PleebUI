import html
import io
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path, PurePosixPath, PureWindowsPath
from urllib.parse import urljoin
from urllib.request import Request, urlopen


STABLE_EXTERNAL = re.compile(
    r"(?m)^  (?P<path>[^:\n]+):\n"
    r"    url: (?P<url>https://[^\n]+)\n"
    r"    tag: latest-stable(?:\n    path: (?P<subpath>[^\n]+))?$"
)


def read_url(url):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "PleebUI-packaging"}
    token = os.environ.get("GITHUB_OAUTH")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    request = Request(url, headers=headers)
    with urlopen(request, timeout=30) as response:
        return response.read()


def resolve_github(url):
    repo = url.removeprefix("https://github.com/").removesuffix(".git")
    release = json.loads(read_url(f"https://api.github.com/repos/{repo}/releases/latest"))

    tag = release.get("tag_name")
    if release.get("draft") is not False or release.get("prerelease") is not False or not tag:
        raise ValueError(f"{repo} did not return a published stable release")

    ref = f"refs/tags/{tag}"
    result = subprocess.run(
        ["git", "ls-remote", url, ref, f"{ref}^{{}}"],
        check=True, capture_output=True, text=True, timeout=60,
    )
    refs = dict(line.split()[::-1] for line in result.stdout.splitlines())
    commit = refs.get(f"{ref}^{{}}", refs.get(ref))
    if not commit or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError(f"{repo} has no Git ref for its stable release {tag}")

    return url, commit, tag


def latest_curse_file(url):
    page = 0
    while True:
        result = json.loads(read_url(
            f"{url}?pageIndex={page}&pageSize=50&sort=dateCreated&sortDescending=true"
        ))
        files = result["data"]
        stable = [file for file in files if file["releaseType"] == 1
                  and file["status"] == 4 and not file.get("isEarlyAccessContent")]
        if stable:
            file = max(stable, key=lambda file: (file["dateCreated"], file["id"]))
            return f"{url}/{file['id']}/download", file["displayName"]
        if len(files) < 50:
            raise ValueError(f"{url} has no published stable file")
        page += 1


def latest_wowace_file(url):
    while url:
        page = read_url(url).decode("utf-8")
        rows = re.findall(r'<tr class="project-file-list-item">.*?</tr>', page, re.S)
        for row in rows:
            if 'title="Release"' in row:
                link = re.search(r'href="([^"]+/download)"', row)
                name = re.search(r'data-name="([^"]+)"', row)
                if not link or not name:
                    raise ValueError(f"{url} has incomplete stable-file metadata")
                return urljoin(url, html.unescape(link[1])), html.unescape(name[1])
        next_page = re.search(r'<a href="([^"]+)" rel="next" data-next-page', page)
        url = urljoin(url, html.unescape(next_page[1])) if next_page else None
    raise ValueError("No published stable WowAce file was found")


def snapshot_package(url, destination):
    # The packager consumes Git externals; snapshot published ZIP bytes in runner temp.
    destination.mkdir()
    with zipfile.ZipFile(io.BytesIO(read_url(url))) as archive:
        for entry in archive.infolist():
            path = PurePosixPath(entry.filename)
            if (path.is_absolute() or PureWindowsPath(entry.filename).drive
                    or ".." in path.parts or ".git" in path.parts or "\\" in entry.filename):
                raise ValueError(f"Unsafe archive path: {entry.filename}")
            if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError(f"Archive symlink is not supported: {entry.filename}")
            target = destination.joinpath(*path.parts)
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(entry))
    git = ["git", "-C", str(destination)]
    subprocess.run(git + ["init", "-q"], check=True)
    subprocess.run(git + ["-c", "core.autocrlf=false", "add", "--force", "--all"], check=True)
    subprocess.run(git + ["-c", "user.name=PleebUI packaging", "-c", "user.email=packaging@pleebui.invalid",
                         "commit", "-q", "-m", "Snapshot published stable library file"], check=True)
    commit = subprocess.check_output(git + ["rev-parse", "HEAD"], text=True).strip()
    return destination.as_uri(), commit


def resolve_external(match, cache, staging, entry_files=()):
    url = match["url"]
    if url not in cache:
        if url.startswith("https://github.com/"):
            cache[url] = (*resolve_github(url), None)
        else:
            if url.startswith("https://www.wowace.com/projects/"):
                download, name = latest_wowace_file(url)
            elif url.startswith("https://www.curseforge.com/api/v1/mods/"):
                download, name = latest_curse_file(url)
            else:
                raise ValueError(f"Unsupported stable-release metadata source: {url}")
            repo = staging / str(len(cache))
            snapshot_url, commit = snapshot_package(download, repo)
            cache[url] = snapshot_url, commit, name, repo

    snapshot_url, commit, name, repo = cache[url]
    subpath = match["subpath"]
    if subpath and repo:
        # Validate against the staged archive rather than silently packaging an empty folder.
        if not (repo / subpath).is_dir():
            raise ValueError(f"{url} release {name} is missing {subpath}")
        prefix = "Libs/" + match["path"].removeprefix("PackagerLibs/") + "/"
        for entry in entry_files:
            if entry.startswith(prefix) and not (repo / subpath / entry.removeprefix(prefix)).is_file():
                raise ValueError(f"{url} release {name} cannot load {entry}")

    print(f"{match['path']}: latest stable {name} ({commit})")
    block = f"  {match['path']}:\n    url: {snapshot_url}\n    type: git\n    commit: {commit}"
    if url.startswith("https://www.wowace.com/projects/"):
        block += f"\n    curse-slug: {url.split('/')[4]}"
    return block + (f"\n    path: {subpath}" if subpath else "")


def resolve_metadata(source, staging, entry_files=()):
    externals = source.split("externals:\n", 1)[1].split("\n\n", 1)[0]
    if len(re.findall(r"(?m)^  [^ #\n][^\n]*:", externals)) != len(STABLE_EXTERNAL.findall(externals)):
        raise ValueError("Every fetched library must have a stable-release metadata source")
    cache = {}
    staging.mkdir()
    resolved, count = STABLE_EXTERNAL.subn(lambda match: resolve_external(match, cache, staging, entry_files), source)
    if not count or "tag: latest-stable" in resolved:
        raise ValueError("Stable-release external configuration was not fully resolved")
    return resolved


if __name__ == "__main__":
    source, destination = map(Path, sys.argv[1:])
    entry_files = [node.attrib["file"].replace("\\", "/")
                   for node in ET.parse(source.parent / "Bootstrap.xml").iter() if "file" in node.attrib]
    resolved = resolve_metadata(source.read_text(encoding="utf-8"), destination.parent / "stable-libraries", entry_files)
    destination.write_text(resolved, encoding="utf-8", newline="\n")
