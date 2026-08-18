# Asset Load Library

Asset Load Library (ALL) is self explanatory based on the name.

The supported formats should be:
1. Texture ids
2. Asset Ids
3. Image Urls
4. Workspace Files

## Requirements

For all features the enviorment should provide:

- `writefile`
- `readfile`
- `isfile`
- `makefolder`
- `isfolder`
- `listfiles`
- `delfile`
- `getcustomasset` or `getsynasset`
- `request`, `http_request`, `syn.request`, or `http.request`

If no request function exists, the library falls back to `game:HttpGet` for basic downloads.

## Loading

Initalize the library using

```lua
loadstring(game:HttpGet('https://raw.githubusercontent.com/Alana86521/Asset-Load-Library/refs/heads/main/README.md'))()
```

To use it you can call:

```lua
getgenv().AssetLibrary
```

It also returns the library table, so environments with a file loader can use the returned value directly.

```lua
local assets = getgenv().AssetLibrary
```

## Supported Sources

### Numeric Roblox ID

```lua
local image = assets.load(1234567890)
imageLabel.Image = image
```

### Roblox ID String

```lua
local image = assets.load("1234567890")
```

### `rbxassetid://`

```lua
local image = assets.load("rbxassetid://1234567890")
```

### Roblox Asset URL

```lua
local image = assets.load("https://www.roblox.com/library/1234567890/example")
```

The numeric ID is extracted instead of downloading the webpage.

### Native Roblox Asset Paths

These pass through unchanged:

```lua
local image = assets.load("rbxasset://textures/ui/GuiImagePlaceholder.png")
```

Supported prefixes:

- `rbxasset://`
- `rbxgameasset://`
- `rbxthumb://`

### External Image URL

```lua
local image, path = assets.load("https://example.com/icon.png")

imageLabel.Image = image

print(image)
print(path)
```

The file is downloaded into the current cache folder and then registered with `getcustomasset` or `getsynasset`.

### Existing Executor File

```lua
local image = assets.load("assets/icon.png")
imageLabel.Image = image
```

Or:

```lua
local image = assets.file("assets/icon.png")
```

## Cache

The default cache folder is:

```text
AssetLibrary/cache
```

External URLs are hashed so repeated calls reuse the same downloaded file.

```lua
local path, cached = assets.download("https://example.com/icon.png")

print(path)
print(cached)
```

`cached` is `true` if an existing cached copy was reused.

## API

### `assets.load(source, opts?)`

Resolves a supported source into a Roblox-ready asset string.

```lua
local asset, path = assets.load(source, opts)
```

Returns:

- `asset`: usable Roblox content string
- `path`: local workspace path for files, otherwise `nil`

Examples:

```lua
local a = assets.load(1234567890)
local b = assets.load("rbxassetid://1234567890")
local c = assets.load("https://example.com/image.png")
local d = assets.load("images/icon.png")
```

### `assets.download(url, opts?)`

Downloads an external image without registering it as a Roblox asset.

```lua
local path, cached = assets.download("https://example.com/icon.png")
```

Returns:

- `path`: enviorment workspace path
- `cached`: whether an existing cached file was reused

### `assets.file(path)`

Registers an existing file.

```lua
local image = assets.file("assets/icon.png")
```

Returns the result from `getcustomasset` or `getsynasset`.

### `assets.set(instance, property, source, opts?)`

Loads an asset and assigns it directly to an instance property.

```lua
assets.set(imageLabel, "Image", "https://example.com/icon.png")
assets.set(decal, "Texture", 1234567890)
```

The property defaults to `Image`:

```lua
assets.set(imageLabel, nil, "https://example.com/icon.png")
```

Returns:

```lua
asset, path
```

### `assets.preload(source, opts?)`

Loads an asset and passes it to `ContentProvider:PreloadAsync`.

```lua
local asset, path, success, err = assets.preload("https://example.com/icon.png")

if not success then
    warn(err)
end
```

Returns:

- `asset`
- `path`
- `success`
- `err`

### `assets.clear()`

Deletes files inside the current cache folder.

```lua
local success, err = assets.clear()

if not success then
    warn(err)
end
```

### `assets.setfolder(path)`

Changes the cache folder.

```lua
assets.setfolder("example/assets")
```

Nested folders are created when the enviorment supports `makefolder`.

### `assets.getfolder()`

Returns the active cache folder.

```lua
print(assets.getfolder())
```

### `assets.supported()`

Returns detected API support.

```lua
local support = assets.supported()

for name, available in pairs(support) do
    print(name, available)
end
```

Possible fields:

```text
request
customasset
writefile
readfile
isfile
makefolder
listfiles
delfile
```

## Options

Options are passed as the second argument to `load`, `download`, `set`, or `preload`.

### `force`

Redownload the URL even if a cached copy exists.

```lua
local image = assets.load("https://example.com/icon.png", {
    force=true
})
```

### `name`

Uses a custom cached filename.

```lua
local image = assets.load("https://example.com/icon.png", {
    name="logo.png"
})
```

Result:

```text
AssetLibrary/cache/logo.png
```

The extension can be omitted:

```lua
local image = assets.load("https://example.com/icon.png", {
    name="logo"
})
```

The library detects and adds the image extension.

### `ext`

Forces the expected image format.

```lua
local image = assets.load("https://example.com/image?id=123", {
    ext="png"
})
```

Supported values:

- `png`
- `jpg`
- `jpeg`
- `webp`
- `gif`
- `bmp`

### `headers`

Adds HTTP headers when the enviorment request API supports them.

```lua
local image = assets.load("https://example.com/private-image", {
    headers={
        ["Authorization"]="femboys",
        ["User-Agent"]="meowing"
    }
})
```

## Extension Detection

For external URLs, ALL tries to detect the format using:

1. `opts.ext`
2. HTTP `Content-Type`
3. Binary file signature
4. URL extension

Meaning extensionless image URLs still work:

```lua
local image = assets.load("https://example.com/api/image?id=123")
```

## Supported Image Formats

- PNG
- JPEG/JPG
- WebP
- GIF
- BMP

Display support can still depend on the enviorment.

## Full Example

```lua
local assets = getgenv().AssetLibrary

assets.setfolder("example/assets")

local logo = assets.load("https://example.com/logo.png", {
    name="logo.png"
})

local icon = assets.load(1234567890)

imageLabel.Image = logo
otherImageLabel.Image = icon

local support = assets.supported()

for name, available in pairs(support) do
    print(name, available)
end
```
