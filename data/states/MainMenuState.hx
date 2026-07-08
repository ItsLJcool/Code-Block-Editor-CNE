
function update(elapsed:Float) {
	if (FlxG.keys.justPressed.K) FlxG.switchState(new ModState('EditorTest'));
}