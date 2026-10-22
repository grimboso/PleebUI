local _, ns = ...

local Presentation = ns.Presentation or {}
ns.Presentation = Presentation

local Adapters = Presentation.Adapters or {}
Presentation.Adapters = Adapters

local REQUIRED_METHODS = {
  "Create",
  "ApplyStyle",
  "ApplyGeometry",
  "ApplyVisibility",
  "BindDataProvider",
  "Release",
}

function Presentation.Register(key, adapter)
  if type(key) ~= "string" or key == "" or type(adapter) ~= "table" then
    return nil
  end

  for index = 1, #REQUIRED_METHODS do
    local method = REQUIRED_METHODS[index]
    if type(adapter[method]) ~= "function" then
      return nil
    end
  end

  Adapters[key] = adapter
  return adapter
end

function Presentation.Get(key)
  return Adapters[key]
end

function Presentation.Read(provider, key, fallback, instance, state)
  if type(provider) == "function" then
    local value = provider(key, instance, state)
    if value ~= nil then
      return value
    end
    return fallback
  end

  if type(provider) ~= "table" then
    return fallback
  end

  local getter = provider.Get
  if type(getter) == "function" then
    local value = getter(provider, key, instance, state)
    if value ~= nil then
      return value
    end
  end

  local value = provider[key]
  if value ~= nil then
    return value
  end

  return fallback
end

function Presentation.Create(key, parent, context)
  local adapter = Adapters[key]
  if not adapter then
    return nil
  end

  local instance = adapter.Create(parent, context or {})
  if instance then
    instance.__puiPresentationKey = key
  end
  return instance
end

function Presentation.Apply(key, instance, state, provider)
  local adapter = Adapters[key]
  if not adapter or not instance then
    return nil
  end

  state = state or {}
  adapter.BindDataProvider(instance, provider, state)
  adapter.ApplyStyle(instance, state)
  adapter.ApplyGeometry(instance, state)
  adapter.ApplyVisibility(instance, state)
  return instance
end

function Presentation.Release(instance)
  if not instance then
    return
  end

  local adapter = Adapters[instance.__puiPresentationKey]
  if adapter then
    adapter.Release(instance)
  end
end

local P = select(1, ns.Pleebug:DropIn(Presentation, { name = "Core.Presentation" }))
Presentation.Register = P:Def("Presentation.Register", Presentation.Register)
Presentation.Get = P:Def("Presentation.Get", Presentation.Get)
Presentation.Read = P:Def("Presentation.Read", Presentation.Read)
Presentation.Create = P:Def("Presentation.Create", Presentation.Create)
Presentation.Apply = P:Def("Presentation.Apply", Presentation.Apply)
Presentation.Release = P:Def("Presentation.Release", Presentation.Release)
