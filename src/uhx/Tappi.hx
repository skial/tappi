package uhx;

import haxe.io.Eof;
import sys.io.File;
import sys.io.Process;

#if neko
import neko.vm.Loader;
#end

using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 * Icelandic for plugin
 */
class Tappi {
	
	public static var paths:Array<String> = [];
	public static var matches:Array<String> = [];
	public static var libraries:Array<String> = [];
	
	public static var classes:Map<String, Class<Dynamic>> = new Map();
	
	public static var quiet:Bool = false;
	public static var haxelib:Bool = false;
	
	public static function load():Void {
		var cwd = Sys.getCwd().normalize();
		
		if (haxelib) searchHaxelib();
		
		paths = paths.map( function(p) return p.normalize() );
		paths = paths.filter( function(p) return p != null && p != '' && p.exists() );
		
		for (lib in libraries) {
			var location = '';
			
			for (path in paths) if (!classes.exists( lib )) {
				var local = '$cwd/$lib.n'.normalize();
				var remote = '$path/$lib.n'.normalize();
				
				for (v in [local, remote]) if (v.exists()) {
					location = v;
					break;
				}
				
			}
			
			if (location != '') {
				matches.push( location );
				
			} else {
				if (!quiet) Sys.println( 'The $lib plugin could not be found.' );
				
			}
			
		}
		
		loadModules();
		
	}
	
	public static function loadModules():Void {
		for (match in matches) {
			if (!quiet) Sys.println( 'Loading $match...' );
			var lib = match.withoutDirectory() + '.n';
			Loader.local().addPath( match.replace( lib, '' ) );
			classes.set( lib.withoutExtension(), Loader.local().loadModule( match.withoutExtension() ).execute() );
		}
	}
	
	public static function reset():Void {
		paths = [];
		matches = [];
		libraries = [];
		haxelib = false;
		classes = new Map();
	}
	
	private static function searchHaxelib():Void {
		var A = 'A'.code, Z = 'Z'.code;
		var a = 'a'.code, z = 'z'.code;
		var n0 = '0'.code, n9 = '9'.code;
		var args = [];
		var output = '';
		
		for (lib in libraries) {
			var process = new Process('haxelib', ['path', lib]);
			output += process.stdout.readAll().toString();
			process.exitCode();
			process.close();
		}
		
		var parts = output.split( '\n' );
		if (parts.length > 0) for (part in parts) if(part.indexOf( 'not installed' ) == -1) {
			var c = part.charCodeAt(0);
			
			if (c >= A && c <= Z || c >= a && c <= z || c >= n0 && c <= n9) {
				part = part.rtrim().normalize();
				
				if (part.exists()) {
					// Go up a directory as `haxelib path` returns the `src` directory.
					var bits = part.removeTrailingSlashes().split('/');
					bits.pop();
					
					var path = bits.join( '/' );
					if (paths.indexOf( path ) == -1) paths.push( path );
					
				}
				
			}
		}
	}
	
}