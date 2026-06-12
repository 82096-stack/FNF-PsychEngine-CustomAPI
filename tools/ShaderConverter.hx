package tools;

import haxe.macro.Expr;
import haxe.macro.Context;
import sys.io.File;
import sys.FileSystem;
import haxe.Json;

/**
 * ShaderConverter — Build-time tool that extracts GLSL shader source
 * from Psych Engine's @:glFragmentSource / @:glVertexSource metadata
 * and converts them to bgfx-compatible .sc shader files.
 *
 * The .sc files are then compiled by shaderc into platform-specific
 * binary shaders (.bin) for Metal, D3D11/D3D12, Vulkan (SPIR-V), and OpenGL.
 *
 * Usage:
 *   haxe --run tools.ShaderConverter
 *
 * Output:
 *   assets/shaders/<name>.<profile>.fs.sc   (bgfx shader source)
 *   assets/shaders/<name>.<profile>.vs.sc
 *   assets/shaders/<name>.<profile>.fs.bin  (compiled binary, after shaderc)
 *   assets/shaders/<name>.<profile>.vs.bin
 */
class ShaderConverter
{
	// Profile names used by shaderc
	static var PROFILES:Array<String> = [
		"s_5_0",    // DirectX 11/12
		"metal",    // Metal (macOS/iOS)
		"spirv",    // Vulkan
		"440",      // OpenGL 4.4
		"120",      // OpenGL 2.1 / GLSL 1.20 (fallback)
	];

	// Map Haxe shader source files to their output names
	static var SHADERS:Array<ShaderDef> = [
		{name: "sprite_default", file: null, hasVertex: true},  // Built-in default
		{name: "color_swap",     file: "source/shaders/ColorSwap.hx", hasVertex: true},
		{name: "rain",          file: "source/shaders/RainShader.hx", hasVertex: true},
		{name: "wiggle",        file: "source/shaders/WiggleEffect.hx", hasVertex: false},
		{name: "overlay",       file: "source/shaders/OverlayShader.hx", hasVertex: false},
		{name: "rgb_palette",   file: "source/shaders/RGBPalette.hx", hasVertex: false},
		{name: "pixel_splash",  file: "source/objects/NoteSplash.hx", hasVertex: false},
	];

	static var outputDir:String = "assets/shaders/compiled";

	public static function main():Void
	{
		trace("=== ShaderConverter — GLSL to bgfx .sc ===\n");

		// Ensure output directory exists
		if (!FileSystem.exists(outputDir))
			FileSystem.createDirectory(outputDir);

		// Write the default sprite shader (built-in)
		writeDefaultSpriteShader();

		// Process each shader file
		for (shader in SHADERS)
		{
			if (shader.file == null) continue; // Skip built-in (already done)

			trace('Processing: ${shader.name} (${shader.file})');
			if (!FileSystem.exists(shader.file))
			{
				trace('  SKIP: file not found');
				continue;
			}

			var content = File.getContent(shader.file);
			var fragmentSrc = extractGLSL(content, "glFragmentSource");
			var fragmentHdr = extractGLSL(content, "glFragmentHeader");
			var vertexSrc   = extractGLSL(content, "glVertexSource");
			var vertexHdr   = extractGLSL(content, "glVertexHeader");

			// Combine header + source
			var fsFull = (fragmentHdr != null ? fragmentHdr + "\n" : "") + (fragmentSrc != null ? fragmentSrc : "");
			var vsFull = (vertexHdr != null ? vertexHdr + "\n" : "") + (vertexSrc != null ? vertexSrc : "");

			if (fsFull.trim() == "")
			{
				trace('  WARNING: no fragment source found, skipping');
				continue;
			}

			// Convert to bgfx format and write per-profile
			for (profile in PROFILES)
			{
				var fsBgfx = convertToBgfx(fsFull, "fragment", shader.name);
				var vsBgfx = convertToBgfx(vsFull != "" ? vsFull : getDefaultVertexGLSL(), "vertex", shader.name);

				var fsPath = '${outputDir}/${shader.name}.${profile}.fs.sc';
				var vsPath = '${outputDir}/${shader.name}.${profile}.vs.sc';

				File.saveContent(fsPath, fsBgfx);
				File.saveContent(vsPath, vsBgfx);
			}

			trace('  -> ${PROFILES.length} profiles written to ${outputDir}/${shader.name}.*.sc');
		}

		trace('\n=== Done. Next: run shaderc to compile .sc -> .bin ===');
		trace('shaderc -f <file>.fs.sc -o <file>.fs.bin --type fragment --platform linux -p 440');
		trace('shaderc -f <file>.vs.sc -o <file>.vs.bin --type vertex   --platform linux -p 440');
	}

	static function writeDefaultSpriteShader():Void
	{
		var defaultVS = getDefaultVertexGLSL();
		var defaultFS =
'$input v_texcoord0, v_color0

#include <bgfx_shader.sh>

SAMPLER2D(s_tex, 0);

void main()
{
	vec4 texColor = texture2D(s_tex, v_texcoord0);
	gl_FragColor = texColor * v_color0;
}
';
		for (profile in PROFILES)
		{
			var vsBgfx = convertToBgfx(defaultVS, "vertex", "sprite_default");
			var fsBgfx = convertToBgfx(defaultFS, "fragment", "sprite_default");
			File.saveContent('${outputDir}/sprite_default.${profile}.vs.sc', vsBgfx);
			File.saveContent('${outputDir}/sprite_default.${profile}.fs.sc', fsBgfx);
		}
		trace('Wrote sprite_default shader');
	}

	static function getDefaultVertexGLSL():String
	{
		return
'$input a_position, a_texcoord0, a_color0
$output v_texcoord0, v_color0

#include <bgfx_shader.sh>

void main()
{
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0, 1.0));
	v_texcoord0 = a_texcoord0;
	v_color0 = a_color0;
}
';
	}

	/**
	 * Extract GLSL source from @:metadata("...") annotations in Haxe source.
	 * Handles both single-line strings and multi-line string concatenation.
	 */
	static function extractGLSL(haxeSource:String, metadataName:String):String
	{
		var pattern = '@:${metadataName}(\'';
		var idx = haxeSource.indexOf(pattern);
		if (idx == -1)
		{
			// Try with double quotes
			pattern = '@:${metadataName}("';
			idx = haxeSource.indexOf(pattern);
		}
		if (idx == -1) return null;

		idx += pattern.length;

		// Find the matching closing quote.
		// Handle escaped quotes within the string.
		var result = new StringBuf();
		var quote = haxeSource.charAt(idx - 1); // ' or "
		var i = idx;

		while (i < haxeSource.length)
		{
			var c = haxeSource.charAt(i);

			if (c == "\\" && i + 1 < haxeSource.length)
			{
				var next = haxeSource.charAt(i + 1);
				if (next == quote || next == "\\")
				{
					result.add(next);
					i += 2;
					continue;
				}
				result.add(c);
				i++;
				continue;
			}

			if (c == quote) break;

			result.add(c);
			i++;
		}

		// Unescape control characters
		var src = result.toString();
		src = StringTools.replace(src, "\\n", "\n");
		src = StringTools.replace(src, "\\t", "\t");
		src = StringTools.replace(src, "\\r", "\r");

		return src;
	}

	/**
	 * Convert raw GLSL to bgfx-compatible shader source.
	 *
	 * bgfx uses a GLSL variant with:
	 * - $input / $output instead of attribute / varying
	 * - bgfx_shader.sh include for uniforms (u_modelViewProj, etc.)
	 * - gl_FragColor for output (compatible)
	 * - SAMPLER2D macro for texture samplers
	 */
	static function convertToBgfx(glslSource:String, type:String, shaderName:String):String
	{
		var result = glslSource;

		// Remove OpenFL-specific uniform declarations (bgfx provides its own)
		// openfl_Matrix, openfl_Alpha, openfl_ColorMultiplier, openfl_ColorOffset
		// openfl_HasColorTransform, openfl_TextureSize, openfl_TextureCoord
		result = removeLineMatching(result, "openfl_Matrix");
		result = removeLineMatching(result, "openfl_Alpha");
		result = removeLineMatching(result, "openfl_ColorMultiplier");
		result = removeLineMatching(result, "openfl_ColorOffset");
		result = removeLineMatching(result, "openfl_HasColorTransform");
		result = removeLineMatching(result, "openfl_TextureSize");
		result = removeLineMatching(result, "openfl_TextureCoord");

		// Replace attribute with $input (bgfx convention)
		result = replaceRegex(result, ~/attribute\s+\w+\s+(\w+);/g, ''); // Remove, handled by $input
		result = replaceRegex(result, ~/varying\s+(\w+\s+)(\w+);/g, ''); // Remove, handled by $output

		// Replace texture2D with texture2D (compatible) but ensure SAMPLER2D is used
		// bgfx shader uses SAMPLER2D macro
		if (result.indexOf('SAMPLER2D') == -1 && result.indexOf('texture2D') != -1)
		{
			// Already uses texture2D — bgfx GLSL supports it natively
		}

		// Comment out #pragma header (bgfx doesn't use it)
		result = StringTools.replace(result, "#pragma header", "// #pragma header (removed for bgfx)");

		// Add bgfx include if not present
		if (result.indexOf('#include <bgfx_shader.sh>') == -1)
		{
			result = '#include <bgfx_shader.sh>\n' + result;
		}

		// Add header comment
		result = '// ${shaderName}.${type}.sc — converted from Psych Engine GLSL for bgfx\n' + result;

		return result;
	}

	static function removeLineMatching(source:String, keyword:String):String
	{
		var lines = source.split("\n");
		var out:Array<String> = [];
		for (line in lines)
		{
			if (line.indexOf(keyword) == -1) out.push(line);
		}
		return out.join("\n");
	}

	static function replaceRegex(source:String, regex:EReg, replacement:String):String
	{
		return regex.replace(source, replacement);
	}
}

typedef ShaderDef = {
	var name:String;
	var file:Null<String>;
	var hasVertex:Bool;
}
