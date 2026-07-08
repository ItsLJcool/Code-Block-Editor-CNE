
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


class ScriptExpressions {

	public static var PRINTER = new Printer();
	public static function stringify(expr:Expr):String {
		var buf = new StringBuf();
		switch(expr.e) {
			case ExprDef.EBlock(e): 
				for (expr in e) {
					buf.add(PRINTER.exprToString(expr));
					buf.add(";\n");
				}
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

	public var variables:Array<VariableContainer> 	= [];
	public var functions:Array<FunctionContainer> 	= [];
	public var imports:Array<ImportContainer> 		= [];

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
		var printer = new Printer();
		var buf = new StringBuf();
		if (imports.length > 0) {
			buf.add("/* region Imports */\n\n");
			for (container in imports) buf.add(stringify(container.toExpr()));
			buf.add("\n/* endregion */\n");
		}
		if (variables.length > 0) {
			buf.add("\n/* region Variables */\n\n");
			for (container in variables) buf.add(stringify(container.toExpr()));
			buf.add("\n/* endregion */\n");
		}
		if (functions.length > 0) {
			buf.add("\n/* region Functions */\n\n");
			for (container in functions) buf.add(stringify(container.toExpr()));
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
				// Expr, Array<Expr>
				// todo: save this in an array and keep its relative line in the code, since it can break if we move it from it's original position
			// default: trace('Unknown expr: ${expr.e}');
		}
	}

	public function addVariable(
		name:String, ?type:Expr.CType, ?expr:Expr,
		?isPublic:Bool, ?isStatic:Bool, ?isPrivate:Bool, ?isFinal:Bool, ?isInline:Bool,
		?get:Expr.FieldPropertyAccess, ?set:Expr.FieldPropertyAccess,
		?isVar:Bool
	):VariableContainer {
		var c = new VariableContainer(name, type, expr, isPublic, isStatic, isPrivate, isFinal, isInline, get, set, isVar);
		variables.push(c);
		return c;
	}

	public function addFunction(
		args:Array<Expr.Argument>, ?expr:Expr, ?name:String, ?ret:Expr.CType,
		?isPublic:Bool, ?isStatic:Bool, ?isOverride:Bool, ?isPrivate:Bool, ?isFinal:Bool, ?isInline:Bool
	):FunctionContainer {
		var c = new FunctionContainer(args, expr, name, ret, isPublic, isStatic, isOverride, isPrivate, isFinal, isInline);
		functions.push(c);
		return c;
	}

	public function addImport(class_name:String, ?as_name:String, ?isUsing:Bool):ImportContainer {
		var c = new ImportContainer(class_name, as_name, isUsing);
		imports.push(c);
		return c;
	}
}