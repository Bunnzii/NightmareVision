package funkin.objects.nodes;

import flixel.FlxObject;
import flixel.util.FlxAxes;

// TODO DOCS
class MenuItemNode extends FlxBasic
{
	public var targetY:Int = 0;
	
	// public var targetX:Int = 0; //maybe
	public var scrollAxis:FlxAxes = XY;
	
	public var startingPosition:FlxPoint = FlxPoint.get(0, 0);
	
	public var distancePerItem:FlxPoint = FlxPoint.get(20, 120);
	
	/**
	 * Additional offset applied to `root` when copying `tracked`'s position.
	 */
	public var positionOffset:FlxPoint = FlxPoint.get();
	
	public var root:Null<FlxObject> = null;
	
	public var speed:Float = 0.16;
	
	public function new(root:FlxObject)
	{
		super();
		this.root = root;
		startingPosition.set(root.x, root.y);
	}
	
	public function snapToPosition():Void
	{
		if (root != null)
		{
			if (scrollAxis.x)
			{
				root.x = (targetY * distancePerItem.x) + startingPosition.x + positionOffset.x;
			}
			
			if (scrollAxis.y)
			{
				root.y = (targetY * distancePerItem.y) + startingPosition.y + positionOffset.y;
			}
		}
	}
	
	override function update(elapsed:Float):Void
	{
		if (root != null)
		{
			final lerpRate:Float = FlxMath.getElapsedLerp(speed, elapsed);
			
			if (scrollAxis.x)
			{
				root.x = FlxMath.lerp(root.x, (targetY * distancePerItem.x) + startingPosition.x + positionOffset.x, lerpRate);
			}
			
			if (scrollAxis.y)
			{
				root.y = FlxMath.lerp(root.y, (targetY * distancePerItem.y) + startingPosition.y + positionOffset.y, lerpRate);
			}
		}
		
		super.update(elapsed);
	}
	
	override function destroy()
	{
		startingPosition = FlxDestroyUtil.put(startingPosition);
		distancePerItem = FlxDestroyUtil.put(distancePerItem);
		positionOffset = FlxDestroyUtil.put(positionOffset);
		super.destroy();
	}
}
