# Adding a language to Waypath+

Player-facing text goes through `RG.L["English text"]`, which returns the English text unless a translation is loaded.

1. Create `Locales/<code>.lua` (for example `Locales/deDE.lua`):

```lua
local _, RG = ...
RG.AddLocale("deDE", {
  ["Route"] = "Route",
  ["Gear guide"] = "Ausruestungsguide",
})
```

2. Add the file to both `.toc` files after `Core.lua`.
3. Only the strings you list are translated; everything else stays English.

Most of the add-on's text is not wrapped yet: new and changed code should use `RG.L[...]`, and older screens are moved over as a language is added.
