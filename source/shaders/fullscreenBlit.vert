$input a_position, a_texcoord0
$output v_texcoord0

#include <bgfx_shader.sh>

void main()
{
	// bgfx fullscreen triangle — uses gl_VertexID (mapped to [[vertex_id]] on Metal
	// via bgfx_shader.sh). Generates clip-space positions covering the entire viewport.
	float x = float(gl_VertexID == 1 ?  3.0 : -1.0);
	float y = float(gl_VertexID == 2 ?  3.0 : -1.0);
	gl_Position = vec4(x, y, 0.0, 1.0);
	v_texcoord0 = vec2(
		(gl_VertexID == 1 ? 2.0 : 0.0),
		(gl_VertexID == 2 ? 2.0 : 0.0)
	);
}
