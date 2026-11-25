package funkin.backend;

import haxe.io.Bytes;
import haxe.io.Path;

import lime.graphics.opengl.GL;
import lime.utils.UInt8Array;

import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.textures.RectangleTexture;

private typedef DDSInfo =
{
	var width:Int;
	var height:Int;
	var glFormat:Int;
	var dataOffset:Int;
	var dataSize:Int;
	var premultiplied:Bool;
}

@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.textures.TextureBase)
class DDSLoader
{
	public static var enabled:Bool = true;

	static inline final DDS_MAGIC:Int = 0x20534444;
	static inline final PF_FOURCC:Int = 0x4;

	static inline final FOURCC_DXT1:Int = 0x31545844;
	static inline final FOURCC_DXT2:Int = 0x32545844;
	static inline final FOURCC_DXT3:Int = 0x33545844;
	static inline final FOURCC_DXT4:Int = 0x34545844;
	static inline final FOURCC_DXT5:Int = 0x35545844;
	static inline final FOURCC_DX10:Int = 0x30315844;
	
	static inline final GL_COMPRESSED_RGBA_S3TC_DXT1_EXT:Int = 0x83F1;
	static inline final GL_COMPRESSED_RGBA_S3TC_DXT3_EXT:Int = 0x83F2;
	static inline final GL_COMPRESSED_RGBA_S3TC_DXT5_EXT:Int = 0x83F3;
	static inline final GL_COMPRESSED_RGBA_BPTC_UNORM:Int = 0x8E8C;
	
	public static function siblingPath(path:String):Null<String>
	{
		if (!enabled) return null;
		
		final ext = Path.extension(path).toLowerCase();
		
		if (ext == 'dds') return FunkinAssets.exists(path) ? path : null;
		if (ext != 'png') return null;
		
		final dds = Path.withoutExtension(path) + '.dds';
		return FunkinAssets.exists(dds) ? dds : null;
	}
	
	public static inline function hasSibling(path:String):Bool
	{
		return siblingPath(path) != null;
	}
	
	public static function load(path:String):Null<BitmapData>
	{
		final ddsPath = siblingPath(path);
		if (ddsPath == null) return null;
		
		final context:Null<Context3D> = Lib.current?.stage?.context3D;
		if (context == null)
		{
			trace('DDS: no context3D available, cannot load [$ddsPath]');
			return null;
		}
		
		var bytes:Bytes;
		try
		{
			bytes = FunkinAssets.getBytes(ddsPath);
		}
		catch (e)
		{
			trace('DDS: failed to read [$ddsPath]: ${e.message}');
			return null;
		}
		
		final info = parse(bytes, ddsPath);
		if (info == null) return null;
		
		return upload(context, bytes, info, ddsPath);
	}
	
	static function parse(bytes:Bytes, name:String):Null<DDSInfo>
	{
		if (bytes.length < 128 || bytes.getInt32(0) != DDS_MAGIC || bytes.getInt32(4) != 124)
		{
			trace('DDS: [$name] is not a valid dds file');
			return null;
		}
		
		final height = bytes.getInt32(12);
		final width = bytes.getInt32(16);
		final pixelFlags = bytes.getInt32(80);
		final fourCC = bytes.getInt32(84);
		
		if (width <= 0 || height <= 0)
		{
			trace('DDS: [$name] has invalid dimensions');
			return null;
		}
		
		if ((pixelFlags & PF_FOURCC) == 0)
		{
			trace('DDS: [$name] is uncompressed, only DXT1/DXT3/DXT5/BC7 are supported');
			return null;
		}
		
		var dataOffset = 128;
		var glFormat = 0;
		var blockSize = 0;
		var premultiplied = false;
		
		switch (fourCC)
		{
			case FOURCC_DXT1:
				glFormat = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
				blockSize = 8;
			case FOURCC_DXT2 | FOURCC_DXT3:
				glFormat = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
				blockSize = 16;
			case FOURCC_DXT4 | FOURCC_DXT5:
				glFormat = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
				blockSize = 16;
			case FOURCC_DX10:
				if (bytes.length < 148)
				{
					trace('DDS: [$name] has a truncated DX10 header');
					return null;
				}
				
				dataOffset = 148;
				final dxgi = bytes.getInt32(128);
				final miscFlags2 = bytes.getInt32(144);
				premultiplied = (miscFlags2 & 0x7) == 0x2;
				
				switch (dxgi)
				{
					case 70 | 71 | 72:
						glFormat = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
						blockSize = 8;
					case 73 | 74 | 75:
						glFormat = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
						blockSize = 16;
					case 76 | 77 | 78:
						glFormat = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
						blockSize = 16;
					case 97 | 98 | 99:
						glFormat = GL_COMPRESSED_RGBA_BPTC_UNORM;
						blockSize = 16;
					default:
						trace('DDS: [$name] uses unsupported DXGI format $dxgi');
						return null;
				}
			default:
				trace('DDS: [$name] uses an unsupported format (fourCC 0x${StringTools.hex(fourCC, 8)})');
				return null;
		}
		
		final dataSize = Std.int((width + 3) / 4) * Std.int((height + 3) / 4) * blockSize;
		
		if (dataOffset + dataSize > bytes.length)
		{
			trace('DDS: [$name] is truncated');
			return null;
		}
		
		return {
			width: width,
			height: height,
			glFormat: glFormat,
			dataOffset: dataOffset,
			dataSize: dataSize,
			premultiplied: premultiplied
		};
	}
	
	static function upload(context:Context3D, bytes:Bytes, info:DDSInfo, name:String):Null<BitmapData>
	{
		final texture:RectangleTexture = context.createRectangleTexture(info.width, info.height, Context3DTextureFormat.BGRA, false);
		texture.__premultiplyAlpha = info.premultiplied;
		
		context.__bindGLTexture2D(texture.__textureID);

		var guard = 0;
		while (GL.getError() != GL.NO_ERROR && guard++ < 16) {}
		
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
		
		GL.compressedTexImage2D(GL.TEXTURE_2D, 0, info.glFormat, info.width, info.height, 0, info.dataSize, UInt8Array.fromBytes(bytes, info.dataOffset, info.dataSize));
		
		final err = GL.getError();
		if (err != GL.NO_ERROR)
		{
			trace('DDS: GL error 0x${StringTools.hex(err, 4)} uploading [$name] (is this format supported by your GPU/driver?)');
			texture.dispose();
			return null;
		}
		
		return BitmapData.fromTexture(texture);
	}
}
