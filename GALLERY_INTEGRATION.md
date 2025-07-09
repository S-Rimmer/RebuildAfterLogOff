# Azure Compute Gallery Integration Changes

This document outlines the modifications made to support Azure Compute Gallery images in the AVD VM rebuild solution.

## Changes Made

### 1. PowerShell Script Updates (`AVD-CheckAndRebuildAtLogoff.ps1`)

**Key Improvements:**
- **Image Type Detection**: Added logic to differentiate between Azure Compute Gallery and marketplace images
- **Gallery Image Parsing**: Proper parsing of gallery image resource IDs
- **Version Management**: Automatic latest version detection for gallery images when version not specified
- **Flexible Parameter Passing**: Dynamic parameter building based on image type

**Code Changes:**
- Added `$isGalleryImage` variable to detect image type using regex pattern matching
- Implemented proper gallery image ID parsing: `/subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/galleries/.../images/.../versions/...`
- Added marketplace image format support: `Publisher:Offer:Sku:Version`
- Updated template parameter building to conditionally include `useGalleryImage` flag
- Removed hardcoded marketplace image parameters from function signature

### 2. UI Definition Updates (`uiDefinition.json`)

**New Features:**
- **Image Type Selection**: Added dropdown to choose between "Azure Compute Gallery" and "Marketplace Image"
- **Dynamic UI Elements**: Conditional visibility based on selected image type
- **Gallery Browser**: Integration with Azure API to browse available galleries and images
- **Marketplace Input**: Manual entry fields for marketplace image details with validation

**UI Sections Added:**
- Image type selector dropdown
- Azure Compute Gallery selection with API integration
- Gallery image selection with automatic latest version support
- Marketplace image configuration section with validation regex patterns

### 3. Template Spec Requirements (`sample-templatespec.bicep`)

**New Template Features:**
- **Conditional Image Reference**: Uses different imageReference properties based on `useGalleryImage` parameter
- **Gallery Image Support**: Direct resource ID reference for gallery images
- **Marketplace Image Support**: Traditional publisher/offer/sku/version structure
- **Parameter Validation**: Proper parameter typing and descriptions

**Template Parameters:**
```bicep
param useGalleryImage bool = true
param imageId string = ''  // Gallery image resource ID
param imagePublisher string = ''  // Marketplace parameters
param imageOffer string = ''
param imageSku string = ''
param imageVersion string = ''
```

## Image Format Examples

### Azure Compute Gallery Image
```
/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/myRG/providers/Microsoft.Compute/galleries/myGallery/images/Win10Image/versions/1.0.0
```

### Marketplace Image
```
MicrosoftWindowsDesktop:Windows-10:20h2-evd:latest
```

## Benefits of These Changes

1. **Flexibility**: Support for both custom gallery images and marketplace images
2. **Version Management**: Automatic latest version detection for gallery images
3. **Improved UI**: Better user experience with dynamic form elements
4. **Validation**: Proper input validation and error handling
5. **Future-Proof**: Template Spec design supports both image types seamlessly

## Migration Notes

**For Existing Deployments:**
- Update your Template Spec to use the new conditional image reference pattern
- Existing marketplace image configurations will continue to work with the new format
- Gallery images can be adopted incrementally

**For New Deployments:**
- Use the updated UI to select image type during deployment
- Gallery images are recommended for standardized corporate environments
- Marketplace images remain suitable for standard Microsoft-provided images

## Testing Recommendations

1. **Gallery Image Testing**: Deploy with a gallery image and verify latest version detection
2. **Marketplace Image Testing**: Deploy with marketplace image using new format
3. **Template Spec Validation**: Ensure your Template Spec handles both image types correctly
4. **UI Flow Testing**: Test the deployment UI with both image type selections
