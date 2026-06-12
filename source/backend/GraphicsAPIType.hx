package backend;

/**
 * Graphics Rendering API type enum.
 * Separated to avoid module name conflicts with GraphicsAPI class.
 */
enum abstract GraphicsAPIType(String) from String to String
{
	var Auto = "Auto";
	var DirectX12 = "DirectX 12";
	var Vulkan = "Vulkan";
	var Metal = "Metal";
	var OpenGL = "OpenGL";
}
