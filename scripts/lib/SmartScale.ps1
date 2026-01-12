<#
.SYNOPSIS
    Smart Scale Plugin for WSL Image Clipboard Helper.
    Optimizes image resolution for LLM Vision APIs (Claude, GPT-4o, Gemini).

.DESCRIPTION
    This plugin scales down images that exceed 1568px (long edge) to reduce
    token consumption while maintaining high recognition accuracy.
    
    The 1568px threshold is derived from:
    - Claude 3.5: Official "1.15 megapixels" recommendation
    - OpenAI GPT-4o: Optimal balance for 512x512 tile calculation
    - Google Gemini: Reasonable slice count for dynamic tiling
    
    Uses System.Drawing (GDI+) for zero-dependency scaling.

.NOTES
    Author: Smart Scale Plugin
    Version: 1.0.0
    Requires: PowerShell 5.1+, .NET Framework (System.Drawing)
#>

# Configuration: Universal Safe Long Edge Limit
$script:MAX_LONG_EDGE = 1568

function Optimize-ImageObject {
    <#
    .SYNOPSIS
        Scales down an image if its long edge exceeds the threshold.
    
    .PARAMETER Image
        The System.Drawing.Image object to process.
    
    .OUTPUTS
        System.Drawing.Image - The processed image (scaled or pass-through).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Drawing.Image]$Image
    )

    $width = $Image.Width
    $height = $Image.Height
    $maxDim = [Math]::Max($width, $height)

    # Pass-through: No scaling needed
    if ($maxDim -le $script:MAX_LONG_EDGE) {
        return $Image
    }

    # Calculate scale ratio
    $ratio = $script:MAX_LONG_EDGE / $maxDim
    $newWidth = [int][Math]::Round($width * $ratio)
    $newHeight = [int][Math]::Round($height * $ratio)

    # Create scaled bitmap with high-quality interpolation
    $scaledBitmap = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
    
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($scaledBitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        # Draw the original image onto the scaled bitmap
        $destRect = New-Object System.Drawing.Rectangle(0, 0, $newWidth, $newHeight)
        $srcRect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
        $graphics.DrawImage($Image, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally {
        if ($graphics) { $graphics.Dispose() }
    }

    # Dispose original image to free memory
    $Image.Dispose()

    return $scaledBitmap
}
