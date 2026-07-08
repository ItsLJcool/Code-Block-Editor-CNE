
import haxe.ds.ObjectMap;
import haxe.ds.IntMap;

import hscript.Expr;
import hscript.Expr.ExprDef;
import hscript.Expr.Const;
import hscript.Expr.CType;
import hscript.Parser;
import hscript.Printer;

import haxe.ds.StringMap;

import funkin.backend.scripting.Script;
import funkin.backend.scripting.HScript;

import StringBuf;
using StringTools;

class ExprContainer {
	public var expr:Null<Expr>;

	public var pmin:Int = 0;
	public var pmax:Int = 0;
	public var origin:String = "ExprContainer_HScript";
	public var line:Int = 0;

	public function new(expr:Null<Expr>) { this.expr = expr; }

	public function exprOrigin(_expr:Null<Expr>):Void {
		if (_expr == null) return;
		this.pmin = _expr.pmin;
		this.pmax = _expr.pmax;
		this.origin = _expr.origin;
		this.line = _expr.line;
	}

	public function toExpr():Expr {
		return new Expr((expr ?? ExprDef.EVar("error_expContainer")), this.pmin, this.pmax, this.origin, this.line);
	}
}

class VariableContainer extends ExprContainer {
	var name:String;
	var type:Expr.CType;

	var isPublic:Bool;
	var isStatic:Bool;
	var isPrivate:Bool;
	var isFinal:Bool;
	var isInline:Bool;

	var get:Expr.FieldPropertyAccess;
	var set:Expr.FieldPropertyAccess;

	var isVar:Bool; // idk what isVar does but cool
	function new(name, type, expr, isPublic, isStatic, isPrivate, isFinal, isInline, get, set, isVar) {
		super(expr);
		this.name = name;
		this.type = type;
		this.isPublic = isPublic;
		this.isStatic = isStatic;
		this.isPrivate = isPrivate;
		this.isFinal = isFinal;
		this.isInline = isInline;
		this.get = get;
		this.set = set;
		this.isVar = isVar;
	}

	override public function toExpr():Expr {
		return new Expr(
			ExprDef.EVar(name, type, expr, isPublic, isStatic, isPrivate, isFinal, isInline, get, set, isVar),
			this.pmin, this.pmax, '_VarContainer_', this.line
		);
	}
}

class FunctionContainer extends ExprContainer {
	var args:Array<Expr.Argument>;
	var name:String;
	var ret:Expr.CType;

	var isPublic:Bool;
	var isStatic:Bool;
	var isOverride:Bool;
	var isPrivate:Bool;
	var isFinal:Bool;
	var isInline:Bool;

	function new(args, expr, name, ret, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline) {
		super(expr);
		this.args = args;
		this.name = name;
		this.ret = ret;
		this.isPublic = isPublic;
		this.isStatic = isStatic;
		this.isOverride = isOverride;
		this.isPrivate = isPrivate;
		this.isFinal = isFinal;
		this.isInline = isInline;
	}

	public function addExpr(_expr:Expr):Bool {
		switch (this.expr.e) { case ExprDef.EBlock(exprs): exprs.push(_expr); return true; }
		return false;
	}

	public function insertExpr(index:Int, _expr:Expr):Bool {
		switch (this.expr.e) { case ExprDef.EBlock(exprs): exprs.insert(index, _expr); return true; }
		return false;
	}

	override public function toExpr():Expr {
		return new Expr(
			ExprDef.EFunction(args, expr, name, ret, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline),
			this.pmin, this.pmax, '_FunctionContainer_', this.line
		);
	}
}

class ImportContainer extends ExprContainer {
	var class_name:String;
	var as_name:String;
	var isUsing:Bool;

	function new(class_name, as_name, isUsing) {
		super(null);
		this.class_name = class_name;
		this.as_name = as_name;
		this.isUsing = isUsing;
	}

	override public function toExpr():Expr {
		return new Expr(
			ExprDef.EImport(class_name, as_name, isUsing),
			this.pmin, this.pmax, '_ImportContainer_', this.line
		);
	}
}

class CallContainer extends ExprContainer {
	var params:Array<Expr>;

	function new(expr:Expr, params:Array<Expr>) {
		super(expr);
		this.params = params;
	}

	override public function toExpr():Expr {
		return new Expr(
			ExprDef.ECall(expr, params),
			this.pmin, this.pmax, '_CallContainer_', this.line
		);
	}
}

class CustomClassContainer extends ExprContainer {
	var name:String;
	var fields:Array<Expr>;

	var extend:Null<String>;
	var interfaces:Array<String>;

	var isFinal:Bool;
	var isPrivate:Bool;

	function new(name, fields, extend, interfaces, isFinal, isPrivate) {
		super(null);
		this.name = name;
		this.fields = fields;
		this.extend = extend;
		this.interfaces = interfaces;
		this.isFinal = isFinal;
		this.isPrivate = isPrivate;
	}

	override public function toExpr():Expr {
		return new Expr(
			ExprDef.EClass(name, fields, extend, interfaces, isFinal, isPrivate),
			this.pmin, this.pmax, '_CustomClassContainer_', this.line
		);
	}
}

class ScriptExpressions {

	public static var PRINTER = new Printer();
	
	// TODO: Fix EClass printing.
	public static function stringify(expr:Expr, ?prefix:String):String {
		var buf = new StringBuf();
		buf.add(prefix ?? '');
		switch(expr.e) {
			case ExprDef.EBlock(e): 
				for (expr in e) {
					buf.add(PRINTER.exprToString(expr));
					buf.add(";\n");
				}
			case ExprDef.EClass(name, fields, extend, interfaces, fnal):
				var isFinal = fnal != null && fnal;
				if (isFinal) buf.add('final ');
				buf.add('class $name');
				if (extend != null) buf.add(' extends $extend');
				for (_interface in interfaces) buf.add(' implements $_interface');

				buf.add(" {\n");
				for( e in fields ) buf.add(stringify(e));
				buf.add("}\n");
			default:
				buf.add(PRINTER.exprToString(expr));
				buf.add(";\n");
		}
		return buf.toString();
	}

	final parser = HScript.initParser();
	private var AST:Expr;
	private var _code:String;

	public static function unravel_debug(expr:Expr) {
		if (expr == null) return;
		switch (expr.e) {
			case ExprDef.EConst(c): trace('Const: $c');
			case ExprDef.EIdent(i): trace('Ident: $i');
			case ExprDef.EVar(n, t, expr, isPublic, isStatic, isPrivate, isFinal, isInline, get, set, isVar):
				trace('Var (debug) | n: $n | t: $t | expr: $expr | isPublic: $isPublic | isStatic: $isStatic | isPrivate: $isPrivate | isFinal: $isFinal | isInline: $isInline | get: $get | set: $set | isVar: $isVar');
				unravel_debug(expr);
			case ExprDef.EParent(expr):
				trace('EParent (debug) | expr: $expr');
				unravel_debug(expr);
			case ExprDef.EBlock(exprs):
				trace('EBlock (debug) | exprs: $exprs');
				for (e in exprs) unravel_debug(e);
			case ExprDef.EField(expr, f, safe):
				trace('Field (debug) | expr: $expr | f: $f | safe: $safe');
				unravel_debug(expr);
			case ExprDef.EBinop(binop, e1, e2):
				trace('Binop (debug) | binop: $binop | e1: $e1 | e2: $e2');
				unravel_debug(e1);
				unravel_debug(e2);
			case ExprDef.EUnop(unop, prefix, expr):
				trace('Unop (debug) | unop: $unop | prefix: $prefix | expr: $expr');
				unravel_debug(expr);
			case ExprDef.ECall(expr, params):
				trace('Call (debug) | expr: $expr | params: $params');
				unravel_debug(expr);
				for (p in params) unravel_debug(p);
			case ExprDef.EIf(econd, eif, eelse):
				trace('If (debug) | econd: $econd | eif: $eif | eelse: $eelse');
				unravel_debug(econd);
				unravel_debug(eif);
				unravel_debug(eelse);
			case ExprDef.EWhile(econd, expr):
				trace('While (debug) | econd: $econd | expr: $expr');
				unravel_debug(econd);
				unravel_debug(expr);
			case ExprDef.EFor(v, itExpr, expr, ithv):
				trace('For (debug) | v: $v | itExpr: $itExpr | expr: $expr | ithv: $ithv');
				unravel_debug(itExpr);
				unravel_debug(expr);
			case ExprDef.EBreak: trace('Break');
			case ExprDef.EContinue: trace('Continue');
			case ExprDef.EFunction(args, expr, name, ret_CType, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline):
				trace('Function (debug) | args: $args | expr: $expr | name: $name | ret: $ret_CType | isPublic: $isPublic | isStatic: $isStatic | isOverride: $isOverride | isPrivate: $isPrivate | isFinal: $isFinal | isInline: $isInline');
				for (a in args) {
					trace('Argument (debug) | name: ${a.name} | CType: ${a.t} | optional: ${a.opt} | value: ${a.value}');
					unravel_debug(a.value);
				}
				unravel_debug(expr);
			case ExprDef.EReturn(expr):
				trace('EReturn (debug) | expr: $expr');
				unravel_debug(expr);
			case ExprDef.EEArray(expr. index):
				trace('EArray (debug) | expr: $expr | index: $index');
				unravel_debug(expr);
				unravel_debug(index);
			case ExprDef.EArrayDecl(exprs, wantedType_CType):
				trace('EArrayDecl (debug) | exprs: $exprs | wantedType: $wantedType_CType');
				for (e in exprs) unravel_debug(e);
			case ExprDef.ENew(cl, params_exprs, paramTypes):
				trace('ENew (debug) | cl: $cl | params_exprs: $params_exprs | paramTypes: $paramTypes');
				for (e in params_exprs) unravel_debug(e);
			case ExprDef.EThrow(expr): unravel_debug(expr);
			case ExprDef.ETry(expr, v, t_CType, ecatch):
				trace('ETry (debug) | expr: $expr | v: $v | t: $t_CType | ecatch: $ecatch');
				unravel_debug(expr);
				unravel_debug(ecatch);
			case ExprDef.EObject(fields):
				trace('EObject (debug) | fields: $fields');
				for (f in fields) {
					trace('ObjectField (debug) | name: ${f.name} | expr: ${f.expr}');
					unravel_debug(f.expr);
				}
			case ExprDef.ETernary(econd, eif, eelse):
				trace('ETernary (debug) | econd: $econd | eif: $eif | eelse: $eelse');
				unravel_debug(econd);
				unravel_debug(eif);
				unravel_debug(eelse);
			case ExprDef.ESwitch(expr, cases, defaultExpr):
				trace('ESwitch (debug) | expr: $expr | cases: $cases | defaultExpr: $defaultExpr');
				for (c in cases) {
					trace('SwitchCase (debug) | values: ${c.values} | expr: ${c.expr}');
					unravel_debug(c.expr);
				}
				unravel_debug(defaultExpr);
			case ExprDef.EDoWhile(econd, expr):
				trace('EDoWhile (debug) | econd: $econd | expr: $expr');
				unravel_debug(econd);
				unravel_debug(expr);
			case ExprDef.EMeta(name, eArgs, expr):
				trace('EMeta (debug) | name: $name | eArgs: $eArgs | expr: $expr');
				for (e in eArgs) unravel_debug(e);
				unravel_debug(expr);
			case ExprDef.ECheckType(expr, t_CType):
				trace('ECheckType (debug) | expr: $expr | t: $t_CType');
				unravel_debug(expr);
			case ExprDef.EPackage(n):
				trace('EPackage (debug) | n: $n');
			case ExprDef.EImport(c, asname, isUsing):
				trace('EImport (debug) | c: $c | asname: $asname | isUsing: $isUsing');
			case ExprDef.EClass(name, fields, extend, interfaces, isFinal, isPrivate):
				trace('EClass (debug) | name: $name | fields: $fields | extend: $extend | interfaces: $interfaces | isFinal: $isFinal | isPrivate: $isPrivate');
				for (f in fields) unravel_debug(f);
			case ExprDef.EEnum(en, isAbstract):
				trace('EEnum (debug) | en: $en | isAbstract: $isAbstract');
			case ExprDef.ECast(e, t_CType):
				trace('ECast (debug) | e: $e | t: $t_CType');
				unravel_debug(e);
			case ExprDef.ERegex(e, flags):
				trace('ERegex (debug) | e: $e | flags: $flags');
			default: trace('Unknown expr: ${expr.e} | expr: $expr');
		}
	}

	public var expressions:Array<ExprContainer> = [];

	public var variables(get, never):Array<VariableContainer>;
	function get_variables():Array<VariableContainer> {
		return expressions.filter((e) -> e is VariableContainer);
	}
	public var functions(get, never):Array<FunctionContainer>;
	function get_functions():Array<FunctionContainer> {
		return expressions.filter(function(e) return e is FunctionContainer);
	}
	public var imports(get, never):Array<ImportContainer>;
	function get_imports():Array<ImportContainer> {
		return expressions.filter(function(e) return e is ImportContainer);
	}
	public var calls(get, never):Array<CallContainer>;
	function get_calls():Array<CallContainer> {
		return expressions.filter(function(e) return e is CallContainer);
	}

	public var custom_classes(get, never):Array<CustomClassContainer>;
	function get_custom_classes():Array<CustomClassContainer> {
		return expressions.filter(function(e) return e is CustomClassContainer);
	}

	public function new(code:String, ?auto_unravel:Bool = true) {
		this._code = code;
		
		reset();

		this.AST = parser.parseString(this._code);
		if (auto_unravel ?? true) unravel(this.AST);
	}

	public function reset() {
		CoolUtil.clear(variables);
		CoolUtil.clear(functions);
		CoolUtil.clear(imports);
		this.AST = null;
		
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		parser.preprocessorValues = Script.getDefaultPreprocessors();
	}

	public function toString():String {
		var buf = new StringBuf();
		buf.add('\n');
		for (container in expressions) buf.add(stringify(container.toExpr()));
		return buf.toString();
	}

	public function prettyString():String {
		var buf = new StringBuf();

		var _imports:Array<ImportContainer> = imports;
		var _variables:Array<VariableContainer> = variables;
		var _functions:Array<FunctionContainer> = functions;
		var _custom_classes:Array<CustomClassContainer> = custom_classes;

		var _calls:Array<CallContainer> = calls;

		var bruh:IntMap<String> = new IntMap();
		bruh.set(expressions.indexOf(_imports[imports.length - 1]), 'imports');
		bruh.set(expressions.indexOf(_variables[variables.length - 1]), 'variables');
		bruh.set(expressions.indexOf(_functions[functions.length - 1]), 'functions');
		bruh.set(expressions.indexOf(_custom_classes[custom_classes.length - 1]), 'custom_classes');
		var values:Array<Int> = [for (int=>c in bruh) int];
		values.sort((a, b) -> return a - b);

		for (c in _calls) {
			// idk if my algorithm is good but w/e
			var idx:Int = 0;
			var target:Int = expressions.indexOf(c);
			var closest:Int = Math.NEGATIVE_INFINITY;
			while (idx < values.length) {
				if (closest < values[idx]) closest = values[idx];
				if (closest > target) {
					closest = values[idx-1];
					break;
				}
				idx++;
			}
			switch (bruh.get(closest)) {
				case 'imports': _imports.push(c);
				case 'variables': _variables.push(c);
				case 'functions': _functions.push(c);
				case 'custom_classes': _custom_classes.push(c);
			}
		}

		if (_imports.length > 0) {
			buf.add("/* region Imports */\n\n");
			for (container in _imports) buf.add(stringify(container.toExpr()));
			buf.add("\n/* endregion */\n");
		}
		if (_custom_classes.length > 0) {
			buf.add("\n/* region Custom Classes */\n\n");
			for (container in _custom_classes) buf.add(stringify(container.toExpr()));
			buf.add("\n/* endregion */\n");
		}
		if (_variables.length > 0) {
			buf.add("\n/* region Variables */\n\n");
			for (container in _variables) buf.add(stringify(container.toExpr()));
			buf.add("\n/* endregion */\n");
		}
		if (_functions.length > 0) {
			buf.add("\n/* region Functions */\n\n");
			for (container in _functions) buf.add(stringify(container.toExpr()));
			buf.add("\n/* endregion */\n");
		}
		return buf.toString();
	}

	public function unravel(expr:Expr, ?prev_expr:Expr = null) {
		if (expr == null) return;
		switch (expr.e) {
			case ExprDef.EBlock(exprs): for (e in exprs) unravel(e, expr);

			case ExprDef.EVar(name, type, expr, isPublic, isStatic, isPrivate, isFinal, isInline, get, set, isVar):
				addVariable(name, type, expr, isPublic, isStatic, isPrivate, isFinal, isInline, get, set, isVar).exprOrigin(prev_expr);

			case ExprDef.EFunction(args, expr, name, ret, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline):
				addFunction(args, expr, name, ret, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline).exprOrigin(prev_expr);

			case ExprDef.EImport(class_name, as_name, isUsing):
				addImport(class_name, as_name, isUsing).exprOrigin(prev_expr);

			case ExprDef.ECall(expr, params):
				addCall(expr, params).exprOrigin(prev_expr);
			case ExprDef.EClass(name, fields, extend, interfaces, isFinal, isPrivate):
				addCustomClass(name, fields, extend, interfaces, isFinal, isPrivate).exprOrigin(prev_expr);

			// default: trace('Unknown expr: ${expr.e}');
		}
	}

	/* region Variables */
	public function addVariable(
		name:String, ?type:Expr.CType, ?expr:Expr,
		?isPublic:Bool, ?isStatic:Bool, ?isPrivate:Bool, ?isFinal:Bool, ?isInline:Bool,
		?get:Expr.FieldPropertyAccess, ?set:Expr.FieldPropertyAccess,
		?isVar:Bool
	):VariableContainer {
		var c = new VariableContainer(name, type, expr, isPublic, isStatic, isPrivate, isFinal, isInline, get, set, isVar);
		expressions.push(c);
		return c;
	}

	public function insertVariable(
		INDEX:Int, 
		name:String, ?type:Expr.CType, ?expr:Expr,
		?isPublic:Bool, ?isStatic:Bool, ?isPrivate:Bool, ?isFinal:Bool, ?isInline:Bool,
		?get:Expr.FieldPropertyAccess, ?set:Expr.FieldPropertyAccess,
		?isVar:Bool
	):VariableContainer {
		var c = new VariableContainer(name, type, expr, isPublic, isStatic, isPrivate, isFinal, isInline, get, set, isVar);
		expressions.insert(INDEX, c);
		return c;
	}
	/* endregion */

	/* region Functions */
	public function addFunction(
		args:Array<Expr.Argument>, ?expr:Expr, ?name:String, ?ret:Expr.CType,
		?isPublic:Bool, ?isStatic:Bool, ?isOverride:Bool, ?isPrivate:Bool, ?isFinal:Bool, ?isInline:Bool
	):FunctionContainer {
		var c = new FunctionContainer(args, expr, name, ret, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline);
		expressions.push(c);
		return c;
	}

	public function insertFunction(
		INDEX:Int,
		args:Array<Expr.Argument>, ?expr:Expr, ?name:String, ?ret:Expr.CType,
		?isPublic:Bool, ?isStatic:Bool, ?isOverride:Bool, ?isPrivate:Bool, ?isFinal:Bool, ?isInline:Bool
	):FunctionContainer {
		var c = new FunctionContainer(args, expr, name, ret, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline);
		expressions.insert(INDEX, c);
		return c;
	}
	/* endregion */

	/* region Imports */
	public function addImport(class_name:String, ?as_name:String, ?isUsing:Bool):ImportContainer {
		var c = new ImportContainer(class_name, as_name, isUsing);
		expressions.push(c);
		return c;
	}

	public function insertImport(
		INDEX:Int,
		class_name:String, ?as_name:String, ?isUsing:Bool
	):ImportContainer {
		var c = new ImportContainer(class_name, as_name, isUsing);
		expressions.insert(INDEX, c);
		return c;
	}
	/* endregion */

	/* region Calls */
	public function addCall(expr:Expr, params:Array<Expr>):CallContainer {
		var c = new CallContainer(expr, params);
		expressions.push(c);
		return c;
	}

	public function insertCall(
		INDEX:Int,
		expr:Expr, params:Array<Expr>
	):CallContainer {
		var c = new CallContainer(expr, params);
		expressions.insert(INDEX, c);
		return c;
	}
	/* endregion */

	/* region Custom Classes */
	public function addCustomClass(
		name:String, fields:Array<Expr>, ?extend:Null<String>, ?interfaces:Array<String>,
		?isFinal:Bool, ?isPrivate:Bool
	):CustomClassContainer {
		var c = new CustomClassContainer(name, fields, extend, interfaces, isFinal, isPrivate);
		expressions.push(c);
		return c;
	}
	
	public function insertCustomClass(
		INDEX:Int,
		name:String, fields:Array<Expr>, ?extend:Null<String>, ?interfaces:Array<String>,
		?isFinal:Bool, ?isPrivate:Bool
	):CustomClassContainer {
		var c = new CustomClassContainer(name, fields, extend, interfaces, isFinal, isPrivate);
		expressions.insert(INDEX, c);
		return c;
	}
	/* endregion */

}