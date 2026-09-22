package funkin.scripting;

import flixel.FlxState;

import funkin.states.*;
import funkin.states.substates.*;

/**
 * Class Containing contants to be used in script to state interaction
 */
class ScriptConstants
{
	/**
	 * Gets the current state
	 * 
	 * if is in playstate and is in the gameover, the gameover will be returned
	 */
	public static inline function getInstance():FlxState
	{
		return PlayState.instance == null ? FlxG.state : PlayState.instance.isDead ? GameOverSubState.instance : PlayState.instance;
	}
}
