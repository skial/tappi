package uhx;

import haxe.crypto.Md5;
import haxe.io.Eof;
import haxe.Serializer;
import sys.io.File;
import sys.io.Process;

#if neko
import neko.vm.Loader;
#end

using Sys;
using StringTools;
using sys.io.File;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 * Icelandic for plugin
 */
class Tappi {
	
	public var paths:Array<String> = [];
	public var matches:Array<String> = [];
	public var libraries:Array<String> = [];
	
	public var classes:Map<String, Class<Dynamic>> = new Map();
	
	public var quiet:Bool = false;
	public var haxelib:Bool = false;
	@:isVar public var cacheDirectory(get, set):String = '';
	
	private var md5Matches:String = '';
	
	public function new(?libraries:Array<String>, ?useHaxelib:Bool = false, ?cacheDirectory:String = '') {
		this.haxelib = useHaxelib;
		this.libraries = libraries == null ? [] : libraries;
		this.cacheDirectory = ('${Sys.getCwd()}/' + (cacheDirectory == '' ? 'tappi/' : '$cacheDirectory/')).normalize();
	}
	
	public function find():Void {
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
				md5Matches += '$location' + location.stat().mtime.getTime();
				
			} else if (!quiet) {
				'The $lib plugin could not be found.'.println();
				
			}
			
		}
		
		md5Matches = Md5.encode( md5Matches );
		
	}
	
	public function load():Void {
		var output = cacheDirectory;
		var current = '$output/current.txt';
		
		if (current.exists() && current.getContent() == md5Matches) {
			if (!quiet) 'Loading from cache...'.println();
			
			Loader.local().addPath( '$md5Matches.n' );
			
			for (match in matches) {
				classes.set( 
					match.withoutDirectory().withoutExtension(),
					Loader.local().loadModule( match.withoutExtension() ).execute() 
				);
			}
			
		} else for (match in matches) {
			if (!quiet) 'Loading $match...'.println();
			
			var lib = match.withoutDirectory();
			var module = Loader.local().loadModule( match.withoutExtension() );
			classes.set( 
				lib.withoutExtension(), 
				module.execute()
			);
			
		}
	}
	
	public function cache():Void {
		var output = cacheDirectory;
		var current = '$output/current.txt';
		
		if (current.exists()) if (current.getContent() == md5Matches) return;
		if (!current.exists()) createDirectory( current );
		
		'$output/current.txt'.saveContent( md5Matches );
		//File.saveContent( '$output/.matches', Serializer.run( matches ) );
		
		#if neko
		var process = new Process( 'nekoc', ['-link', '$output/$md5Matches.n'].concat( matches.map( function(f) return f.withoutExtension() )) );
		var error = process.stderr.readAll().toString().trim();
		
		if (error != '' && !quiet) error.println();
		
		process.exitCode();
		process.close();
		#end
	}
	
	private function searchHaxelib():Void {
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
	
	private function createDirectory(path:String) {
		if (!path.directory().addTrailingSlash().exists()) {
			
			var parts = path.directory().split('/');
			var missing = [parts.pop()];
			
			while (!Path.join( parts ).normalize().exists()) missing.push( parts.pop() );
			
			missing.reverse();
			
			var directory = Path.join( parts );
			for (part in missing) {
				directory = '$directory/$part/'.normalize().replace(' ', '-');
				if (!directory.exists()) FileSystem.createDirectory( directory );
			}
			
		}
	}
	
	private function get_cacheDirectory():String {
		return
		#if neko
		'$cacheDirectory/neko'
		#else
		cacheDirectory
		#end
		.normalize();
	}
	
	private function set_cacheDirectory(v:String):String {
		return cacheDirectory = v;
	}
}