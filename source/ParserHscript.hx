import hscript.Expr;
import hscript.Expr.ExprDef;
import hscript.Expr.Const;
import hscript.Expr.CType;
// import hscript.Expr.FieldPropertyAccess;
import hscript.Parser;
import hscript.Printer;
import hscript.Tools;

import StringBuf;
import Lambda;

using StringTools;

class ParserHscript {
	var buf:StringBuf;
	var tabs:String;

	public function new() {}

	public function exprToString(e:Expr):String {
		buf = new StringBuf();
		tabs = "";
		expr(e);
		return buf.toString();
	}

	public function exprToString(e:Expr):String {
		buf = new StringBuf();
		tabs = "";
		type(e);
		return buf.toString();
	}

	public function add(s:String):Void { buf?.add(s); }

	private function getterString(property:FieldPropertyAccess) {
		trace('property: $property');
		// switch (property) {
		// 	case FieldPropertyAccess.ADefault: add("default, ");
		// 	case FieldPropertyAccess.ANull: add("null, ");
		// 	case FieldPropertyAccess.AGet: add("get, ");
		// 	case FieldPropertyAccess.ADynamic: add("dynamic, ");
		// 	case FieldPropertyAccess.ANever: add("never, ");
		// }
	}

	private function setterString(property:FieldPropertyAccess) {
		trace('property: $property');
		// switch (property) {
		// 	case FieldPropertyAccess.ADefault: add("default");
		// 	case FieldPropertyAccess.ANull: add("null");
		// 	case FieldPropertyAccess.ASet: add("set");
		// 	case FieldPropertyAccess.ADynamic: add("dynamic");
		// 	case FieldPropertyAccess.ANever: add("never");
		// }
	}

	function type(t:CType):Void {
		switch(t) {
			case CType.CTOpt(t):
				add('?');
				type(t);
			case CType.CTPath(path, params):
				add(path.join("."));
				if( params != null ) {
					add("<");
					var first = true;
					for( p in params ) {
						if( first ) first = false else add(", ");
						type(p);
					}
					add(">");
				}
			case CType.CTNamed(name, t):
				add(name);
				add(':');
				type(t);
			case CType.CTFun(args, ret):
				if (Lambda.exists(args, function (a) return a.match(CType.CTNamed(_, _)))) {
					add('(');
					for (a in args)
						switch (a) {
							case CType.CTNamed(_, _): type(a);
							default: type(CType.CTNamed('_', a));
						}
					add(')->');
					type(ret);
				}
			case CType.CTFun(args, ret):
				if( args.length == 0 )
					add("Void -> ");
				else {
					for( a in args ) {
						type(a);
						add(" -> ");
					}
				}
				type(ret);
			case CType.CTAnon(fields):
				add("{");
				var first = true;
				for( f in fields ) {
					if( first ) { first = false; add(" "); } else add(", ");
					add(f.name + " : ");
					type(f.t);
				}
				add(first ? "}" : " }");
			case CType.CTParent(t):
				add("(");
				type(t);
				add(")");
			case CType.CTExpr(e): expr(e);
		}
	}

	function addType(t:CType):Void {
		if ( t == null ) return;
		add(":");
		type(t);
	}

	public function expr(e:Expr):Void {
		if (e == null) {
			add("??NULL??");
			return;
		}
		switch (Tools.expr(e)) {
			case ExprDef.EPackage(n):
				add('package');
				if (n != null) (' $n');
				add(';\n');
			case ExprDef.EImport(c, n, u):
				add('${u ? 'using' : 'import'} $c');
				if (n != null) add(' as $n');
				add(';\n');
			case ExprDef.EClass(name, fields, extend, interfaces, fnal):
				var isFinal = fnal != null && fnal;
				if (isFinal) add('final ');
				add('class $name');
				if (extend != null) add(' extends $extend');
				for (_interface in interfaces) add(' implements $_interface');

				tabs += "\t";
				add(" {\n");

				for (e in fields) {
					add(tabs);
					expr(e);
					// add(";\n");
				}
				tabs = tabs.substr(1);
				add("}\n");
			case ExprDef.EEnum(en, isAbstract):
				if (isAbstract) {
					add('enum abstract ${en.name}(');
					if (en.underlyingType != null) type(en.underlyingType);
					else add('Int');
					add(')');
					if (en.fields.length == 0) {
						add(' {}');
						return;
					}

					tabs += "\t";
					add(" {\n");
					for (e in en.fields) {
						add(tabs);
						add(e.name);
						if (e.value != null) {
							add(" = ");
							expr(e.value);
						}
						add(";\n");
					}
					tabs = tabs.substr(1);
					add("}\n");
				} else {
					add('enum ${en.name}');
					if (en.fields.length == 0) {
						add(' {}');
						return;
					}
					tabs += "\t";
					add(" {\n");
					for (e in en.fields) {
						add(tabs);
						add(e.name);
						if (e.args.length > 0) {
							add("(");
							var first = true;
							for (a in e.args) {
								if (first) first = false
								else add(", ");
								if (a.opt) add("?");
								add(a.name);
								addType(a.t);
							}
							add(')');
						}
						add(";\n");
					}
					tabs = tabs.substr(1);
					add("}\n");
				}
			case ExprDef.ECast(e, t):
				var safe = (t != null);
				add("cast ");
				if (safe) add("(");
				expr(e);
				if (safe) {
					add(", ");
					addType(t);
					add(")");
				}
				add(";\n");
			case ExprDef.ERegex(e, f):
				add('~/$e/$f');
				add(';\n');
			case ExprDef.EConst(c):
				switch (c) {
					case Const.CInt(i): add(i);
					case Const.CFloat(f): add(f);
					case Const.CString(s):
						add('"');
						add(s.split('"')
							.join('\\"')
							.split("\n")
							.join("\\n")
							.split("\r")
							.join("\\r")
							.split("\t")
							.join("\\t"));
						add('"');
				}
				add(";\n");
			case ExprDef.EIdent(v): add(v);
			case ExprDef.EVar(n, t, e, p, s, pr, isFinal, isInline, get, set, _):
				if (p) add("public ");
				else if (pr) add("private ");
				if (s) add("static ");
				if (isInline) add("inline ");
				if (isFinal) add('final $n');
				else add('var $n');

				if (get != null || set != null) {
					add("(");
					getterString(get);
					setterString(set);
					add(")");
				}

				addType(t);
				if (e != null) {
					add(" = ");
					expr(e);
				}
				add(";\n");
			case ExprDef.EParent(e):
				add("(");
				expr(e);
				add(")");
			case ExprDef.EBlock(el):
				if (el.length == 0) {
					add("{}");
				} else {
					tabs += "\t";
					add("{\n");
					for (e in el) {
						add(tabs);
						expr(e);
						add(";\n");
					}
					tabs = tabs.substr(1);
					add("}");
				}
			case ExprDef.EField(e, f, s):
				expr(e);
				add((s == true ? "?." : ".") + f);
			case ExprDef.EBinop(op, e1, e2):
				expr(e1);
				add(' ${op.toString()} ');
				expr(e2);
			case ExprDef.EUnop(op, pre, e):
				if (pre) {
					add(op);
					expr(e);
				} else {
					expr(e);
					add(op);
				}
				add(";\n");
			case ExprDef.ECall(e, args):
				if (e == null) expr(e);
				else {
					switch (Tools.expr(e)) {
						case ExprDef.EField(_), ExprDef.EIdent(_), ExprDef.EConst(_): expr(e);
						default:
							add("(");
							expr(e);
							add(")");
					}
				}
				add("(");
				var first = true;
				for (a in args) {
					if (first) first = false
					else add(", ");
					expr(a);
				}
				add(")");
				add(";\n");
			case ExprDef.EIf(cond, e1, e2):
				add("if ( ");
				expr(cond);
				add(" ) ");
				expr(e1);
				if (e2 != null) {
					add(" else ");
					expr(e2);
				}
			case ExprDef.EWhile(cond, e):
				add("while (");
				expr(cond);
				add(") ");
				expr(e);
			case ExprDef.EDoWhile(cond, e):
				add("do ");
				expr(e);
				add(" while (");
				expr(cond);
				add(")\n");
			case ExprDef.EFor(v, it, e, ithv):
				if (ithv != null) add('for( $ithv => $v in ');
				else add('for( $v in ');
				
				expr(it);
				add(") ");
				expr(e);
				add("\n");
			case ExprDef.EBreak: add("break;");
			case ExprDef.EContinue: add("continue;");
			case ExprDef.EFunction(params, e, name, ret): // TODO: static, public, override
				add("function");
				if (name != null) add(' $name');
				add(" (");
				var first = true;
				for (a in params) {
					if (first) first = false
					else add(", ");

					if (a.opt) add("?");
					add(a.name);
					addType(a.t);
				}
				add(")");
				addType(ret);
				add(" ");
				expr(e);
				add("\n");
			case ExprDef.EReturn(e):
				add("return");
				if (e != null) {
					add(" ");
					expr(e);
				}
				add(";\n");
			case ExprDef.EArray(e, index):
				expr(e);
				add("[");
				expr(index);
				add("]");
			case ExprDef.EArrayDecl(el, _):
				add("[");
				var first = true;
				for (e in el) {
					if (first) first = false
					else add(", ");
					expr(e);
				}
				add("]");
			case ExprDef.ENew(cl, args, params):
				add('new $cl');
				if (params != null) {
					add("<");
					var first = true;
					for (p in params) {
						if (first) first = false
						else add(", ");
						type(p);
					}
					add(">");
				}
				add("(");
				var first = true;
				for (e in args) {
					if (first) first = false
					else add(", ");
					expr(e);
				}
				add(")");
			case ExprDef.EThrow(e):
				add("throw ");
				expr(e);
			case ExprDef.ETry(e, v, t, ecatch):
				add("try ");
				expr(e);
				add(" catch( " + v);
				addType(t);
				add(") ");
				expr(ecatch);
			case ExprDef.EObject(fl):
				if (fl.length == 0) {
					add("{}");
				} else {
					tabs += "\t";
					add("{\n");
					for (f in fl) {
						add(tabs);
						add(f.name + " : ");
						expr(f.e);
						add(",\n");
					}
					tabs = tabs.substr(1);
					add("}");
				}
				add(";\n");
			case ExprDef.ETernary(c, e1, e2):
				expr(c);
				add(" ? ");
				expr(e1);
				add(" : ");
				expr(e2);
			case ExprDef.ESwitch(e, cases, def):
				add("switch( ");
				expr(e);
				add(") {");
				for (c in cases) {
					add("case ");
					var first = true;
					for (v in c.values) {
						if (first) first = false
						else add(", ");
						expr(v);
					}
					add(": ");
					expr(c.expr);
					add(";\n");
				}
				if (def != null) {
					add("default: ");
					expr(def);
					add(";\n");
				}
				add("}");
			case ExprDef.EMeta(name, args, e):
				add("@");
				add(name);
				if (args != null && args.length > 0) {
					add("(");
					var first = true;
					for (a in args) {
						if (first) first = false
						else add(", ");
						expr(e);
					}
					add(")");
				}
				add(" ");
				expr(e);
			case ExprDef.ECheckType(e, t):
				add("(");
				expr(e);
				add(" : ");
				addType(t);
				add(")");
		}
	}
}
