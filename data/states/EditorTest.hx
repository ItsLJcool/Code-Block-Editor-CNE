
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

import flixel.addons.display.FlxBackdrop;

import openfl.display.BitmapData;

import ScriptExpressions;
import Type;

class ExprBlock extends FlxSprite {

	private var container:ExprContainer;
	private var sub_exprs(get, never):Array<Expr>;
	function get_sub_exprs():Array<Expr> {
		var exprs:Array<Expr> = [];
		HscriptTools.map(container.expr, (expr:Expr) -> exprs.push(expr));
		return exprs;
	}

	public var borderSize:Int = 10;

	private var _displayText:FlxText = new FlxText();

	override public function new(c:ExprContainer, ?border:Int = 10) {
		super();
		this.container = c;
		this.borderSize = (border ?? 10);

		color = FlxColor.WHITE;

		_displayText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, 'center', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		antialiasing = true;

		makeSolid(1, 1);
		regen_display();

	}

	public function regen_display() {
		_displayText.text = '${ScriptExpressions.stringify(container.toExpr())}';
		
		var _width:Int = _displayText.width + (borderSize * 0.5);
		var _height:Int = _displayText.height + (borderSize * 0.5);
		setGraphicSize(_width, _height);
		updateHitbox();
	}

	override public function update(elapsed:Float) {
		if (!visible || !exists) return;
		super.update(elapsed);

		_displayText.x = this.x;
		_displayText.y = this.y + 5;
		_displayText.antialiasing = antialiasing;
		_displayText.fieldWidth = this.width;
		_displayText.update(elapsed);
	}

	override public function draw() {
		if (!visible || !active) return;
		super.draw();
		_displayText.draw();
	}

}

class FunctionBlock extends ExprBlock {
	private var _insideText:FlxText = new FlxText();
	private var expr_blocks:Array<ExprBlock> = [];

	private var _inset:Int = 15;

	override public function new(c:FunctionContainer) {
		super(c);

		_insideText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		regen_display();
	}

	override public function regen_display() {
		_displayText.text = 'function ${container.name}';
		
		CoolUtil.clear(expr_blocks);
		for (cont in this.container.varContainers) {
			expr_blocks.push(new ExprBlock(cont, borderSize));
		}
		
		var _width:Int = _displayText.width + (borderSize * 0.5);
		var _height:Int = _displayText.height + (borderSize * 0.5);
		setGraphicSize(_width, _height);
		updateHitbox();
	}

	override public function update(elapsed:Float) {
		if (!visible || !exists) return;
		super.update(elapsed);

		_displayText.x = this.x;
		_displayText.y = this.y + 5;
		_displayText.antialiasing = antialiasing;
		_displayText.fieldWidth = this.width;
		_displayText.update(elapsed);

		var prev_block:ExprBlock = this;
		for (idx=>block in expr_blocks) {
			block.x = this.x + _inset;
			block.y = prev_block.y + prev_block.height + _inset;
			block.antialiasing = antialiasing;
			block.update(elapsed);
			prev_block = block;
		}

		_insideText.x = this.x + _inset;
		_insideText.y = this.y + _displayText.height + _inset;
		_insideText.fieldWidth = this.width;
		_insideText.antialiasing = antialiasing;
		_insideText.update(elapsed);

	}

	override public function draw() {
		if (!visible || !active) return;
		super.draw();
		_displayText.draw();
		for (b in expr_blocks) b.draw();
	}
}

var script_path:String = Paths.getPath("data/test_scripts/test.hx");
// var script_path:String = Paths.getPath("source/ScriptExpressions.hx");
var exprs:ScriptExpressions = new ScriptExpressions(Assets.getText(script_path), false);
exprs.addVariable('myVar', CType.CTPath([Int]), new Expr(ExprDef.EConst(Const.CInt(10)), 0, 0, 'editor_test', 0), false, false, false, false, false, null, null, false);
exprs.unravel(exprs.AST);
/* region test */
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

//endregion

CoolUtil.safeSaveFile('./.test/test.hx', exprs.prettyString());

final grid_size:Int = 115;
var backdrop_bitmap:BitmapData = new BitmapData(grid_size, grid_size, true, FlxColor.TRANSPARENT);
var thickness:Int = 3;
final size:FlxPoint = FlxPoint.weak(0, 0);
backdrop_bitmap.lock();
while (size.x < backdrop_bitmap.width || size.y < backdrop_bitmap.height) {
	if (size.x < backdrop_bitmap.width) {
		for (i in 0...thickness) backdrop_bitmap.setPixel32(size.x, i, FlxColor.WHITE);
		size.x++;
	}
	if (size.y < backdrop_bitmap.height) {
		for (i in 0...thickness) backdrop_bitmap.setPixel32(i, size.y, FlxColor.WHITE);
		size.y++;
	}
}
backdrop_bitmap.unlock();
size.putWeak(); size = null;

var grid_backdrop:FlxBackdrop = new FlxBackdrop(backdrop_bitmap);

function new() {
	FlxG.mouse.visible = true;
	FlxG.camera.bgColor = 0xFF808080;

	grid_backdrop.antialiasing = true;
	add(grid_backdrop);

	var last_block:FunctionBlock = null;
	for (idx=>container in exprs.functions) {
		var block = new FunctionBlock(container);
		block.x = ((last_block?.x ?? 0) + (last_block?.width ?? 0)) + (idx == 0 ? 15 : 250);
		block.y += 25;
		add(block);
		last_block = block;
	}

}

function update(elapsed:Float) {
	var speed:Int = (FlxG.keys.pressed.SHIFT) ? 250 : 150;
	if (FlxG.keys.pressed.W) FlxG.camera.scroll.y -= speed * elapsed;
	else if (FlxG.keys.pressed.S) FlxG.camera.scroll.y += speed * elapsed;
	if (FlxG.keys.pressed.D) FlxG.camera.scroll.x += speed * elapsed;
	else if (FlxG.keys.pressed.A) FlxG.camera.scroll.x -= speed * elapsed;
}

function destroy() {
	FlxG.camera.bgColor = FlxColor.TRANSPARENT;
}