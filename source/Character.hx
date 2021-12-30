package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.Assets;
import haxe.Json;
import haxe.format.JsonParser;
#if sys
import sys.io.File;
import sys.FileSystem;
#else
import js.html.XMLHttpRequest;
import js.html.XMLHttpRequestResponseType;
import js.html.Response;
import js.html.FileReader;
#end

using StringTools;

typedef CharJunk = {
	var anims:Array<AnimationArray>;
	var CharacterImage:String;
	var CharacterScale:Float;
	var CharacterPosition:Array<Float>;
	var CharacterFlipX:Bool;
	var CharacterAntialiasing:Bool;
}

typedef AnimationArray = {
	var Animation:String;
	var AnimName:String;
	var AnimFPS:Int;
	var AnimLOOP:Bool;
	var AnimIndices:Array<Int>;
	var Offsets:Array<Int>;
}

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;
	public var CharPositionUse:Array<Float> = [0, 0];

	public var isPlayer:Bool = false;
	public var IdleDancing:Bool = false;
	public var curCharacter:String = 'bf';

	public var holdTimer:Float = 0;

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;

		switch(curCharacter) {
			default:
				var rawJson:String = "";
				var charPath:String = "";

				#if sys
					var charJsonPath:String = "assets/chars/" + curCharacter + ".json";
					charPath = charJsonPath;
					if(!FileSystem.exists(charPath)) {
						charPath = "assets/chars/bf.json";
					}

					rawJson = File.getContent(charPath);
				#else
					var charJsonPath:String = "./assets/chars/" + curCharacter + ".json";
					charPath = charJsonPath;

					rawJson = whyDoesThisWork(charPath);
					rawJson = rawJson.trim();
				#end

				while (!rawJson.endsWith("}"))
				{
					rawJson = rawJson.substr(0, rawJson.length - 1);
				}

				var json:CharJunk = cast Json.parse(rawJson);

				#if sys
					if(!FileSystem.exists("assets/" + json.CharacterImage + ".txt")) {
						frames = Paths.getSparrowAtlasThing(json.CharacterImage);
					} else {
						frames = Paths.getPackerAtlasThing(json.CharacterImage);
					}
				#else
					var checkStuffs:Bool;
					checkStuffs = checkFileExists("./assets/" + json.CharacterImage + ".txt");
					if(!checkStuffs) {
						frames = Paths.getSparrowAtlasThing(json.CharacterImage);
					} else {
						frames = Paths.getPackerAtlasThing(json.CharacterImage);
					}
				#end

				if(json.CharacterScale != 1) {
					setGraphicSize(Std.int(width * Std.int(json.CharacterScale)));
					updateHitbox();
				}

				flipX = json.CharacterFlipX;
				CharPositionUse = json.CharacterPosition;

				if(json.anims != null && json.anims.length > 0) {
					for(anim in json.anims) {
						var AnimationThing:String = anim.Animation;
						var AnimationNameThing:String = anim.AnimName;
						var AnimationFps:Int = anim.AnimFPS;
						var AnimationLoop:Bool = anim.AnimLOOP;
						var AnimationIndices:Array<Int> = anim.AnimIndices;
						
						if(AnimationIndices != null && AnimationIndices.length > 0) {
							animation.addByIndices(AnimationThing, AnimationNameThing, AnimationIndices, "", AnimationFps, AnimationLoop);
						} else {
							animation.addByPrefix(AnimationThing, AnimationNameThing, AnimationFps, AnimationLoop);
						}

						if(anim.Offsets != null && anim.Offsets.length > 1) {
							addOffset(anim.Animation, anim.Offsets[0], anim.Offsets[1]);
						}
					}
				} else {
					animation.addByPrefix('idle', 'BF idle dance', 24, false);
				} 

				antialiasing = json.CharacterAntialiasing;

				trace("Character " + curCharacter + " loaded with the file " + charPath + "!");

				json = null;
				rawJson = null;
				charPath = null;
		}

		checkIdle();
		dance();

		if (isPlayer)
		{
			flipX = !flipX;

			// Doesn't flip for BF, since his are already in the right place???
			if (!curCharacter.startsWith('bf') && animation.curAnim != null)
			{
				// var animArray
				var oldRight = animation.getByName('singRIGHT').frames;
				animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
				animation.getByName('singLEFT').frames = oldRight;

				// IF THEY HAVE MISS ANIMATIONS??
				if (animation.getByName('singRIGHTmiss') != null)
				{
					var oldMiss = animation.getByName('singRIGHTmiss').frames;
					animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
					animation.getByName('singLEFTmiss').frames = oldMiss;
				}
			}
		}
	}

	#if html5
	public static function whyDoesThisWork(uh:String):String {
		var bloob = new XMLHttpRequest();
		bloob.open('GET', uh, false);
		bloob.send(null);
		return bloob.responseText;
	}

	public static function checkFileExists(uh:String):Bool {
		var bloob = new XMLHttpRequest();
		bloob.open('GET', uh, false);
		bloob.send(null);
		trace(bloob.status);
		trace(bloob.statusText);
		if(bloob.status == 404) {
			return false;
		} else if(bloob.statusText == "Not Found") {
			return false;
		} else {
			return true;
		}
		return false;
	}
	#end

	override function update(elapsed:Float)
	{
		if (!isPlayer && animation.curAnim != null)
		{
			if (animation.curAnim.name.startsWith('sing'))
			{
				holdTimer += elapsed;
			}

			var dadVar:Float = 4;

			if (curCharacter == 'dad')
				dadVar = 6.1;
			if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001)
			{
				dance();
				holdTimer = 0;
			}
		}
		if(animation.curAnim != null) {
			switch (curCharacter)
			{
				case 'gf':
					if (animation.curAnim.name == 'hairFall' && animation.curAnim.finished)
						playAnim('danceRight');
			}
		}

		super.update(elapsed);
	}

	private var danced:Bool = false;

	public function dance()
	{
		if(IdleDancing) {
			danced = !danced;
			if(danced) {
				playAnim('danceRight');
			} else {
				playAnim('danceLeft');
			}
		} else if(animation.getByName('idle') != null) {
			playAnim('idle');
		}
	}

	public function checkIdle() {
		if(animation.getByName('danceLeft') != null && animation.getByName('danceRight') != null) {
			IdleDancing = true;
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if(animation.getByName(AnimName) != null)
			animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);

		if (curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
			{
				danced = true;
			}
			else if (AnimName == 'singRIGHT')
			{
				danced = false;
			}

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
			{
				danced = !danced;
			}
		}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}
}