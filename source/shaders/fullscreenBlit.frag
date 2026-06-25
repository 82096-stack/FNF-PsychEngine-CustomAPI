// Fullscreen Blit Fragment Shader — bgfx compatible
// Samples the low-resolution input texture and outputs to the viewport.
// This is the simplest "upscaler" — bilinear interpolation by the GPU sampler.

$input v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_inputTexture, 0);

void main()
{
	vec4 color = texture2D(s_inputTexture, v_texcoord0);
	gl_FragColor = color;
}
