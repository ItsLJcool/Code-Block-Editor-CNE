
import funkin.backend.scripting.Script;
import funkin.backend.scripting.HScript;

import funkin.backend.assets.ModsFolder;

import flixel.text.FlxTextBorderStyle;

import hscript.Expr;
import hscript.Expr.ExprDef;
import hscript.Expr.Const;
import hscript.Expr.CType;
import hscript.Parser;
import hscript.Printer;
import hscript.Tools as HscriptTools;

import flixel.util.FlxAxes;

import ScriptExpressions;
import Type;

var script_path:String = Paths.getPath("source/ScriptExpressions.hx");
var exprs:ScriptExpressions = new ScriptExpressions(Assets.getText(script_path), false);
// exprs.addVariable('myVar', CType.CTPath([Int]), new Expr(ExprDef.EConst(Const.CInt(10)), 0, 0, 'editor_test', 0), false, false, false, false, false, null, null, false);
exprs.unravel(exprs.AST);
// ScriptExpressions.unravel_debug(exprs.AST);
// HscriptTools.map(exprs.AST, (expr:Expr) -> {
// 	switch (expr.e) {
// 		case ExprDef.EFunction(args, expr, name, ret, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline):
// 			trace('name: $name');
// 			var filtered = exprs.functions.filter((e) -> e.name == name);
// 			var container:FunctionContainer = filtered.pop();
// 			var index:Int = exprs.expressions.indexOf(container);
// 			if (index < 0) return expr;

// 			container.insertExpr(0, 
// 				new Expr(
// 					ExprDef.ECall(
// 						new Expr(ExprDef.EIdent("trace"), 0, 0, 'editor_test', 0),
// 						[new Expr(ExprDef.EIdent("myVar"), 0, 0, 'editor_test', 0)]
// 					), 0, 0, 'editor_test', 0
// 				)
// 			);
// 	}
// 	return expr;
// });
// ScriptExpressions.unravel_debug(exprs.AST);
CoolUtil.safeSaveFile('./.test/test.hx', exprs.toString());

function new() {
	FlxG.camera.bgColor = 0xFF808080;


	for (idx=>container in exprs.variables) {
		var block = new BaseBlock(container.name);
		block.x = (block.width+10) * idx;
		add(block);
	}

}

function destroy() {
	FlxG.camera.bgColor = FlxColor.TRANSPARENT;
}

class BaseBlock extends FlxSprite {

	public var name(default, set):String;
	public function set_name(value:String) {
		name = value;
		_displayText.text = name;
		return value;
	}

	private var _displayText:FlxText;

	override function new(_name:String) {
		super();
		color = FlxColor.WHITE;
		makeSolid(150, 150);
		
		_displayText = new FlxText(0, 0, 0, "");
		_displayText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		this.name = _name;

	}

	override function update(elapsed:Float) {
		if (!visible || !exists) return;
		super.update(elapsed);

		_displayText.x = this.x + 5;
		_displayText.y = this.y + 5;
		_displayText.fieldWidth = this.width;
		_displayText.update(elapsed);

	}

	override function draw() {
		if (!visible || !active) return;
		super.draw();
		_displayText.draw();
	}
}