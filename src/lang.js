/* KampfScript — a tiny language for KampfOS.
 * Tokenizer -> Parser (AST) -> async tree-walking Interpreter with step metering.
 * No JavaScript eval anywhere. Works in the browser (window.KampfScript) and in Node (module.exports).
 */
(function (root) {
  'use strict';

  class KError extends Error {
    constructor(message, line) {
      super(message);
      this.kmsg = message;
      this.line = line || 0;
      this.message = (line ? 'Line ' + line + ': ' : '') + message;
    }
  }
  const OUT_OF_COINS = 'OUT_OF_COINS';

  // ------------------------------------------------------------ Tokenizer
  const KEYWORDS = new Set(['let', 'fn', 'return', 'if', 'else', 'while', 'for', 'in', 'break', 'continue', 'true', 'false', 'nil', 'and', 'or', 'not']);
  const TWO = new Set(['==', '!=', '<=', '>=', '+=', '-=', '*=', '/=', '%=']);
  const ONE = '+-*/%<>=()[]{},.:;!';

  function tokenize(src) {
    const toks = [];
    const stack = []; // open brackets; newlines only count at top level or directly inside { }
    let i = 0, line = 1;
    const push = (type, value, l) => toks.push({ type, value, line: l || line });
    while (i < src.length) {
      const c = src[i];
      if (c === '\n') {
        if (!stack.length || stack[stack.length - 1] === '{') push('nl', '\n');
        line++; i++; continue;
      }
      if (c === ' ' || c === '\t' || c === '\r') { i++; continue; }
      if (c === '#' || (c === '/' && src[i + 1] === '/')) { while (i < src.length && src[i] !== '\n') i++; continue; }
      if (/[0-9]/.test(c) || (c === '.' && /[0-9]/.test(src[i + 1] || ''))) {
        let j = i, dots = 0;
        while (j < src.length && /[0-9.]/.test(src[j])) { if (src[j] === '.') { if (dots || !/[0-9]/.test(src[j + 1] || '')) break; dots++; } j++; }
        if (/[eE]/.test(src[j] || '') && /^[eE][+-]?[0-9]/.test(src.slice(j, j + 3))) { j += /[+-]/.test(src[j + 1]) ? 2 : 1; while (j < src.length && /[0-9]/.test(src[j])) j++; }  // v1.3: 1e6, 2.5e-3
        push('num', parseFloat(src.slice(i, j))); i = j; continue;
      }
      if (/[A-Za-z_]/.test(c)) {
        let j = i; while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++;
        const w = src.slice(i, j);
        push(KEYWORDS.has(w) ? 'kw' : 'id', w); i = j; continue;
      }
      if (c === '"' || c === "'") {
        const q = c, startLine = line; let j = i + 1, s = '';
        while (true) {
          if (j >= src.length || src[j] === '\n') throw new KError('Unterminated string (missing closing ' + q + ')', startLine);
          const d = src[j];
          if (d === q) { j++; break; }
          if (d === '\\') {
            const e = src[j + 1];
            s += e === 'n' ? '\n' : e === 't' ? '\t' : e === '\\' ? '\\' : e === '"' ? '"' : e === "'" ? "'" : e === undefined ? '' : '\\' + e;
            j += 2; continue;
          }
          s += d; j++;
        }
        push('str', s, startLine); i = j; continue;
      }
      if (c === '`') {
        // v1.3 template string: `Hello {name}, you are {age + 1}` — {expr} is evaluated, \{ is a literal brace
        const startLine = line; let j = i + 1, s = ''; const parts = [];
        while (true) {
          if (j >= src.length) throw new KError('Unterminated template string (missing closing `)', startLine);
          const d = src[j];
          if (d === '`') { j++; break; }
          if (d === '\n') line++;
          if (d === '\\') { const e = src[j + 1]; s += e === 'n' ? '\n' : e === 't' ? '\t' : e === undefined ? '' : e; j += 2; continue; }
          if (d === '{') {
            let depth = 1, k = j + 1;
            while (k < src.length && depth) { if (src[k] === '{') depth++; else if (src[k] === '}') depth--; if (depth) k++; }
            if (depth) throw new KError("Template string: '{' was never closed with '}'", line);
            parts.push(s); s = ''; parts.push({ code: src.slice(j + 1, k), line }); j = k + 1; continue;
          }
          s += d; j++;
        }
        parts.push(s); push('tpl', parts, startLine); i = j; continue;
      }
      const two = src.slice(i, i + 2);
      if (two === '++' || two === '--') throw new KError("'" + two + "' isn't KampfScript — write x " + two[0] + "= 1", line);
      if (two === '&&' || two === '||') throw new KError("'" + two + "' isn't KampfScript — use '" + (two === '&&' ? 'and' : 'or') + "'", line);
      if (TWO.has(two)) { push('op', two); i += 2; continue; }
      if (ONE.includes(c)) {
        if (c === '(' || c === '[' || c === '{') stack.push(c);
        if (c === ')' || c === ']' || c === '}') stack.pop();
        push(c === ';' ? 'nl' : 'op', c); i++; continue;
      }
      throw new KError("Unexpected character '" + c + "'", line);
    }
    push('nl', '\n'); push('eof', null);
    return toks;
  }

  // ------------------------------------------------------------ Parser
  function parse(src) {
    const toks = tokenize(src);
    let p = 0;
    const peek = (o = 0) => toks[p + o];
    const describe = (t) => t.type === 'eof' ? 'end of file' : t.type === 'nl' ? 'end of line' : t.type === 'str' ? 'string "' + t.value + '"' : "'" + t.value + "'";
    const is = (type, value) => { const t = toks[p]; return t.type === type && (value === undefined || t.value === value); };
    const isOp = (v) => is('op', v);
    const isKw = (v) => is('kw', v);
    const next = () => toks[p++];
    function expect(type, value, what) {
      if (is(type, value)) return next();
      throw new KError('Expected ' + (what || "'" + value + "'") + ' but found ' + describe(peek()), peek().line);
    }
    const skipNl = () => { while (is('nl')) p++; };

    function program() {
      const body = [];
      skipNl();
      while (!is('eof')) { body.push(statement()); endStmt(); skipNl(); }
      return { type: 'Program', body };
    }
    function endStmt() {
      if (is('nl') || is('eof') || isOp('}')) return;
      const prev = toks[p - 1]; if (prev && prev.type === 'op' && prev.value === '}') return;
      throw new KError('Unexpected ' + describe(peek()) + ' (did you forget a new line or an operator?)', peek().line);
    }
    function block() {
      expect('op', '{', "'{' to start a block");
      const body = [];
      skipNl();
      while (!isOp('}')) {
        if (is('eof')) throw new KError("Missing '}' — a block was never closed", peek().line);
        body.push(statement()); endStmt(); skipNl();
      }
      next();
      return body;
    }
    function params() {
      expect('op', '(', "'(' after fn");
      const ps = [];
      if (!isOp(')')) {
        do { ps.push(expect('id', undefined, 'a parameter name').value); } while (isOp(',') && next());
      }
      expect('op', ')', "')' to close the parameter list");
      return ps;
    }
    function statement() {
      const t = peek(), line = t.line;
      if (t.type === 'kw') {
        switch (t.value) {
          case 'let': {
            next();
            const name = expect('id', undefined, 'a variable name after let').value;
            expect('op', '=', "'=' after the variable name");
            return { type: 'Let', name, value: expr(), line };
          }
          case 'fn':
            if (peek(1).type === 'id') {
              next(); const name = next().value; const ps = params();
              return { type: 'FnDecl', name, params: ps, body: block(), line };
            }
            break;
          case 'if': return ifStmt();
          case 'while': { next(); const cond = expr(); return { type: 'While', cond, body: block(), line }; }
          case 'for': {
            next();
            const name = expect('id', undefined, 'a loop variable name after for').value;
            let name2 = null;   // v1.3: for i, item in list  /  for key, value in map
            if (isOp(',')) { next(); name2 = expect('id', undefined, 'a second loop variable name after the comma').value; }
            expect('kw', 'in', "'in' after the loop variable");
            const iter = expr();
            return { type: 'For', name, name2, iter, body: block(), line };
          }
          case 'return': {
            next();
            const value = (is('nl') || isOp('}') || is('eof')) ? null : expr();
            return { type: 'Return', value, line };
          }
          case 'break': next(); return { type: 'Break', line };
          case 'continue': next(); return { type: 'Continue', line };
        }
      }
      const e = expr();
      if (is('op') && ['=', '+=', '-=', '*=', '/=', '%='].includes(peek().value)) {
        const op = next().value;
        if (!['Ident', 'Index', 'Member'].includes(e.type)) throw new KError("Can't assign to that — left side of '" + op + "' must be a variable, list item or field", line);
        return { type: 'Assign', target: e, op, value: expr(), line };
      }
      return { type: 'ExprStmt', expr: e, line };
    }
    function ifStmt() {
      const line = next().line;
      const cond = expr();
      const then = block();
      let els = null;
      let save = p; skipNl();
      if (isKw('else')) {
        next();
        if (isKw('if')) els = [ifStmt()];
        else els = block();
      } else p = save;
      return { type: 'If', cond, then, else: els, line };
    }

    function expr() { return orExpr(); }
    function orExpr() {
      let l = andExpr();
      while (isKw('or')) { const line = next().line; l = { type: 'Logical', op: 'or', left: l, right: andExpr(), line }; }
      return l;
    }
    function andExpr() {
      let l = notExpr();
      while (isKw('and')) { const line = next().line; l = { type: 'Logical', op: 'and', left: l, right: notExpr(), line }; }
      return l;
    }
    function notExpr() {
      if (isKw('not') || isOp('!')) { const line = next().line; return { type: 'Unary', op: 'not', arg: notExpr(), line }; }
      return cmp();
    }
    function cmp() {
      let l = add();
      while (is('op') && ['==', '!=', '<', '>', '<=', '>='].includes(peek().value)) {
        const t = next(); l = { type: 'Binary', op: t.value, left: l, right: add(), line: t.line };
      }
      return l;
    }
    function add() {
      let l = mul();
      while (isOp('+') || isOp('-')) { const t = next(); l = { type: 'Binary', op: t.value, left: l, right: mul(), line: t.line }; }
      return l;
    }
    function mul() {
      let l = unary();
      while (isOp('*') || isOp('/') || isOp('%')) { const t = next(); l = { type: 'Binary', op: t.value, left: l, right: unary(), line: t.line }; }
      return l;
    }
    function unary() {
      if (isOp('-')) { const line = next().line; return { type: 'Unary', op: '-', arg: unary(), line }; }
      return postfix();
    }
    function postfix() {
      let e = primary();
      while (true) {
        if (isOp('(')) {
          const line = next().line; const args = [];
          if (!isOp(')')) { do { args.push(expr()); } while (isOp(',') && next()); }
          expect('op', ')', "')' to close the function call");
          e = { type: 'Call', callee: e, args, line };
        } else if (isOp('[')) {
          const line = next().line; const index = expr();
          expect('op', ']', "']' after the index");
          e = { type: 'Index', obj: e, index, line };
        } else if (isOp('.')) {
          const line = next().line;
          const t = next();
          if (t.type !== 'id' && t.type !== 'kw') throw new KError("Expected a field name after '.'", line);
          e = { type: 'Member', obj: e, name: t.value, line };
        } else break;
      }
      return e;
    }
    function primary() {
      const t = peek(), line = t.line;
      if (t.type === 'num') { next(); return { type: 'Lit', value: t.value, line }; }
      if (t.type === 'str') { next(); return { type: 'Lit', value: t.value, line }; }
      if (t.type === 'tpl') {
        next();
        const parts = t.value.map(x => {
          if (typeof x === 'string') return x;
          if (!x.code.trim()) throw new KError('Template string: empty {} — put an expression inside, like {name}', x.line);
          const prog = parse(x.code);
          if (prog.body.length !== 1 || prog.body[0].type !== 'ExprStmt') throw new KError('Template string: {' + x.code + '} must be a single expression', x.line);
          return prog.body[0].expr;
        });
        return { type: 'Template', parts, line };
      }
      if (t.type === 'id') { next(); return { type: 'Ident', name: t.value, line }; }
      if (t.type === 'kw') {
        if (t.value === 'true') { next(); return { type: 'Lit', value: true, line }; }
        if (t.value === 'false') { next(); return { type: 'Lit', value: false, line }; }
        if (t.value === 'nil') { next(); return { type: 'Lit', value: null, line }; }
        if (t.value === 'fn') { next(); const ps = params(); return { type: 'FnExpr', params: ps, body: block(), line }; }
      }
      if (isOp('(')) { next(); const e = expr(); expect('op', ')', "')'"); return e; }
      if (isOp('[')) {
        next(); const items = [];
        skipNl();
        if (!isOp(']')) { do { skipNl(); if (isOp(']')) break; items.push(expr()); skipNl(); } while (isOp(',') && next()); }
        skipNl();
        expect('op', ']', "']' to close the list");
        return { type: 'List', items, line };
      }
      if (isOp('{')) {
        next(); const entries = [];
        skipNl();
        while (!isOp('}')) {
          const k = next();
          if (!['id', 'str', 'num', 'kw'].includes(k.type)) throw new KError('Map keys must be names, strings or numbers, found ' + describe(k), k.line);
          expect('op', ':', "':' after the map key");
          entries.push([String(k.value), expr()]);
          skipNl();
          if (isOp(',')) { next(); skipNl(); } else if (!isOp('}')) throw new KError("Expected ',' or '}' in map but found " + describe(peek()), peek().line);
        }
        next();
        return { type: 'MapLit', entries, line };
      }
      throw new KError('Unexpected ' + describe(t), line);
    }
    return program();
  }

  // ------------------------------------------------------------ Values
  class KMap { constructor(obj) { this.m = new Map(); if (obj) for (const k of Object.keys(obj)) this.m.set(k, obj[k]); } }
  class KFunc { constructor(name, params, body, closure) { this.name = name; this.params = params; this.body = body; this.closure = closure; } }
  class KBuiltin { constructor(name, fn, min, max) { this.name = name; this.fn = fn; this.min = min || 0; this.max = max === undefined ? Infinity : max; } }
  class KHandle { constructor(kind, el, extra) { this.kind = kind; this.el = el; Object.assign(this, extra || {}); } }

  class Env {
    constructor(parent) { this.vars = new Map(); this.parent = parent; }
    get(name, line) {
      let e = this;
      while (e) { if (e.vars.has(name)) return e.vars.get(name); e = e.parent; }
      const guess = this.closest(name);
      throw new KError("Unknown name '" + name + "' — " + (guess ? "did you mean '" + guess + "'? (or " : '') + "did you forget 'let " + name + " = ...'?" + (guess ? ')' : ''), line);
    }
    closest(name) {
      let best = null, bd = name.length > 4 ? 2 : 1;
      for (let e = this; e; e = e.parent) for (const k of e.vars.keys()) { const d = editDistance(name, k, bd); if (d <= bd && (!best || d < best[1])) best = [k, d]; }
      return best ? best[0] : null;
    }
    set(name, v) {
      let e = this;
      while (e) { if (e.vars.has(name)) { e.vars.set(name, v); return; } e = e.parent; }
      this.vars.set(name, v);
    }
    define(name, v) { this.vars.set(name, v); }
  }

  function editDistance(a, b, cap) {
    if (Math.abs(a.length - b.length) > cap) return cap + 1;
    const A = a.toLowerCase(), Bs = b.toLowerCase(); let prev = Array.from({ length: Bs.length + 1 }, (_, i) => i);
    for (let i = 1; i <= A.length; i++) { const cur = [i]; for (let j = 1; j <= Bs.length; j++) cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (A[i - 1] === Bs[j - 1] ? 0 : 1)); prev = cur; }
    return prev[Bs.length];
  }
  function typeOf(v) {
    if (v === null || v === undefined) return 'nil';
    if (typeof v === 'number') return 'number';
    if (typeof v === 'string') return 'string';
    if (typeof v === 'boolean') return 'bool';
    if (Array.isArray(v)) return 'list';
    if (v instanceof KMap) return 'map';
    if (v instanceof KFunc || v instanceof KBuiltin) return 'function';
    if (v instanceof KHandle) return v.kind;
    return 'unknown';
  }
  function fmtNum(n) {
    if (Number.isInteger(n)) return String(n);
    if (!isFinite(n)) return n > 0 ? 'infinity' : n < 0 ? '-infinity' : 'nan';
    return String(Math.round(n * 1e10) / 1e10);
  }
  function show(v, nested, seen) {
    seen = seen || new Set();
    if (v === null || v === undefined) return 'nil';
    if (typeof v === 'number') return fmtNum(v);
    if (typeof v === 'string') return nested ? JSON.stringify(v) : v;
    if (typeof v === 'boolean') return String(v);
    if (Array.isArray(v) || v instanceof KMap) {
      if (seen.has(v)) return '...'; seen.add(v);
      if (Array.isArray(v)) return '[' + v.map(x => show(x, true, seen)).join(', ') + ']';
      return '{' + [...v.m.entries()].map(([k, x]) => k + ': ' + show(x, true, seen)).join(', ') + '}';
    }
    if (v instanceof KFunc) return '<fn ' + (v.name || 'anonymous') + '>';
    if (v instanceof KBuiltin) return '<builtin ' + v.name + '>';
    if (v instanceof KHandle) return '<' + v.kind + '>';
    return String(v);
  }
  const truthy = (v) => !(v === false || v === null || v === undefined || v === 0 || v === '');

  class ReturnSig { constructor(v) { this.v = v; } }
  const BREAK = { sig: 'break' }, CONTINUE = { sig: 'continue' };

  const tick = typeof setImmediate === 'function' ? () => new Promise(r => setImmediate(r))
    : typeof MessageChannel === 'function' ? (() => { const ch = new MessageChannel(), q = []; ch.port1.onmessage = () => { const r = q.shift(); if (r) r(); }; return () => new Promise(r => { q.push(r); ch.port2.postMessage(0); }); })()
    : () => new Promise(r => setTimeout(r, 0));

  // ------------------------------------------------------------ Interpreter
  class Interpreter {
    constructor(opts) {
      opts = opts || {};
      this.opts = opts;
      this.maxSteps = opts.maxSteps || 20000;
      this.stepsPerCoin = opts.stepsPerCoin || 1000;
      this.yieldEvery = opts.yieldEvery || 1500;
      this.steps = 0; this.totalSteps = 0; this.coinsSpent = 0;
      this.depth = 0; this.stopped = false;
      // Debug hooks (used by Kompass KampfScript DevTools). All optional, zero cost when null:
      //   hooks.statement(stmt, env) -> may return a Promise to pause (breakpoints / stepping)
      //   hooks.builtin(name, args, line)   every builtin call
      //   hooks.invoke(label, steps, ms, error) after every external callback invocation
      this.hooks = opts.hooks || null;
      this.callStack = [];   // [{name, line}] of KampfScript functions currently running
      this.noDebug = 0;      // >0 while running REPL code: statement hooks are skipped
      this.globals = new Env(null);
      for (const k of Object.keys(CONSTANTS)) this.globals.define(k, CONSTANTS[k]);
      const all = Object.assign({}, coreBuiltins(), opts.builtins || {});
      for (const k of Object.keys(all)) {
        const b = all[k];
        this.globals.define(k, b instanceof KBuiltin ? b : new KBuiltin(k, b.fn, b.min, b.max));
      }
    }
    stop() { this.stopped = true; }
    print(s) { (this.opts.onPrint || console.log)(s); }
    charge(n, line, reason) {
      if (n <= 0) return;
      const ok = this.opts.onCharge ? this.opts.onCharge(n, reason || 'cpu') : true;
      if (!ok) { const e = new KError('💸 Out of coins! The CPU refuses to work for free. Go mine some coins.', line); e.code = OUT_OF_COINS; throw e; }
      this.coinsSpent += n;
      if (this.opts.onMeter) this.opts.onMeter(this);
    }
    async step(line) {
      this.steps++; this.totalSteps++;
      if (this.stopped) throw new KError('Program stopped.', line);
      if (this.steps > this.maxSteps) { const e = new KError('Step limit reached (' + this.maxSteps + ' steps). Infinite loop? Buy more RAM in the Shop.', line); e.code = 'STEP_LIMIT'; throw e; }
      if (this.totalSteps % this.stepsPerCoin === 0) this.charge(1, line, 'cpu');
      if (this.totalSteps % this.yieldEvery === 0) { if (this.opts.onMeter) this.opts.onMeter(this); await tick(); }
    }
    async run(src) {
      const ast = parse(src);
      this.steps = 0;
      if (this.opts.runCost) this.charge(this.opts.runCost, 0, 'run');
      await this.execBlock(ast.body, this.globals);
      return { steps: this.totalSteps, coins: this.coinsSpent };
    }
    // Invoke a KampfScript function from outside (UI callbacks). Each callback gets a fresh step budget.
    async invoke(fn, args, label) {
      if (this.stopped) return null;
      this.steps = 0;
      const h = this.hooks, t0 = h && h.invoke ? Date.now() : 0, s0 = this.totalSteps;
      let err = null;
      try { return await this.callValue(fn, args || [], 0); }
      catch (e) {
        err = e;
        if (e instanceof ReturnSig) { err = null; return e.v; }
        if (this.opts.onError) this.opts.onError(e instanceof KError ? e : new KError(String(e && e.message || e)));
        else throw e;
      } finally {
        if (h && h.invoke) h.invoke(label || (fn && fn.name) || 'callback', this.totalSteps - s0, Date.now() - t0, err);
      }
    }
    // Run source in the live global environment (REPL). Returns the value of the last expression statement.
    async repl(src) {
      const ast = parse(src);
      this.steps = 0; this.noDebug++;
      let last = null;
      try {
        for (const s of ast.body) {
          if (s.type === 'ExprStmt') { await this.step(s.line); last = await this.eval(s.expr, this.globals); }
          else { await this.exec(s, this.globals); last = null; }
        }
      } catch (e) {
        if (e instanceof ReturnSig) return e.v;
        if (e === BREAK || e === CONTINUE) throw new KError("'break'/'continue' used outside of a loop");
        throw e;
      } finally { this.noDebug--; }
      return last;
    }
    async execBlock(stmts, env) {
      for (const s of stmts) await this.exec(s, env);
    }
    async exec(s, env) {
      await this.step(s.line);
      if (this.hooks && this.hooks.statement && !this.noDebug) { const p = this.hooks.statement(s, env, this); if (p) await p; }
      switch (s.type) {
        case 'Let': env.define(s.name, await this.eval(s.value, env)); return;
        case 'FnDecl': env.define(s.name, new KFunc(s.name, s.params, s.body, env)); return;
        case 'ExprStmt': await this.eval(s.expr, env); return;
        case 'Assign': return this.assign(s, env);
        case 'If':
          if (truthy(await this.eval(s.cond, env))) await this.execBlock(s.then, new Env(env));
          else if (s.else) await this.execBlock(s.else, new Env(env));
          return;
        case 'While':
          while (truthy(await this.eval(s.cond, env))) {
            try { await this.execBlock(s.body, new Env(env)); }
            catch (e) { if (e === BREAK) break; if (e === CONTINUE) { await this.step(s.line); continue; } throw e; }
            await this.step(s.line);
          }
          return;
        case 'For': {
          const it = await this.eval(s.iter, env);
          let items;
          if (Array.isArray(it)) items = it.slice();
          else if (typeof it === 'string') items = [...it];
          else if (it instanceof KMap) items = [...it.m.keys()];
          else if (typeof it === 'number') items = Array.from({ length: Math.max(0, Math.floor(it)) }, (_, i) => i);
          else throw new KError("Can't loop over a " + typeOf(it) + ' (use a list, string, map or number)', s.line);
          const pairs = s.name2 !== null && s.name2 !== undefined;
          const vals = pairs ? (Array.isArray(it) ? it.slice() : typeof it === 'string' ? [...it] : it instanceof KMap ? items.map(k => it.m.get(k)) : items) : null;
          if (pairs && !(it instanceof KMap)) items = items.map((_, i) => i);
          for (let n = 0; n < items.length; n++) {
            const v = items[n];
            const e2 = new Env(env); e2.define(s.name, v); if (pairs) e2.define(s.name2, vals[n]);
            try { await this.execBlock(s.body, e2); }
            catch (e) { if (e === BREAK) break; if (e === CONTINUE) continue; throw e; }
            await this.step(s.line);
          }
          return;
        }
        case 'Return': throw new ReturnSig(s.value ? await this.eval(s.value, env) : null);
        case 'Break': throw BREAK;
        case 'Continue': throw CONTINUE;
      }
      throw new KError('Unknown statement ' + s.type, s.line);
    }
    async assign(s, env) {
      let v = await this.eval(s.value, env);
      const t = s.target;
      const combine = async (old) => s.op === '=' ? v : this.binop(s.op[0], old, v, s.line);
      if (t.type === 'Ident') {
        if (s.op !== '=') v = await combine(env.get(t.name, t.line));
        env.set(t.name, v); return;
      }
      const obj = await this.eval(t.obj, env);
      const key = t.type === 'Member' ? t.name : await this.eval(t.index, env);
      if (Array.isArray(obj)) {
        if (typeof key !== 'number') throw new KError('List index must be a number', s.line);
        let i = Math.floor(key); if (i < 0) i += obj.length;
        if (i < 0 || i >= obj.length) throw new KError('List index ' + key + ' is out of range (list has ' + obj.length + ' items)', s.line);
        obj[i] = s.op === '=' ? v : await combine(obj[i]);
      } else if (obj instanceof KMap) {
        const k = String(key);
        obj.m.set(k, s.op === '=' ? v : await combine(obj.m.has(k) ? obj.m.get(k) : null));
      } else throw new KError("Can't set an item on a " + typeOf(obj), s.line);
    }
    binop(op, a, b, line) {
      switch (op) {
        case '+':
          if (typeof a === 'number' && typeof b === 'number') return a + b;
          if (typeof a === 'string' || typeof b === 'string') return show(a) + show(b);
          if (Array.isArray(a) && Array.isArray(b)) return a.concat(b);
          throw new KError("Can't add " + typeOf(a) + ' and ' + typeOf(b), line);
        case '-': case '*': case '/': case '%':
          if (op === '*' && typeof a === 'string' && typeof b === 'number') return a.repeat(Math.max(0, Math.min(10000, Math.floor(b))));
          if (typeof a !== 'number' || typeof b !== 'number') throw new KError("Can't use '" + op + "' on " + typeOf(a) + ' and ' + typeOf(b), line);
          if ((op === '/' || op === '%') && b === 0) throw new KError('Division by zero', line);
          return op === '-' ? a - b : op === '*' ? a * b : op === '/' ? a / b : ((a % b) + b) % b;
        case '==': return eq(a, b);
        case '!=': return !eq(a, b);
        case '<': case '>': case '<=': case '>=':
          if (!((typeof a === 'number' && typeof b === 'number') || (typeof a === 'string' && typeof b === 'string')))
            throw new KError("Can't compare " + typeOf(a) + ' and ' + typeOf(b) + " with '" + op + "'", line);
          return op === '<' ? a < b : op === '>' ? a > b : op === '<=' ? a <= b : a >= b;
      }
      throw new KError('Unknown operator ' + op, line);
    }
    async eval(n, env) {
      switch (n.type) {
        case 'Lit': return n.value;
        case 'Template': { let out = ''; for (const p of n.parts) out += typeof p === 'string' ? p : show(await this.eval(p, env)); return out; }
        case 'Ident': return env.get(n.name, n.line);
        case 'List': { const out = []; for (const it of n.items) out.push(await this.eval(it, env)); return out; }
        case 'MapLit': { const m = new KMap(); for (const [k, v] of n.entries) m.m.set(k, await this.eval(v, env)); return m; }
        case 'FnExpr': return new KFunc(null, n.params, n.body, env);
        case 'Unary': {
          const v = await this.eval(n.arg, env);
          if (n.op === 'not') return !truthy(v);
          if (typeof v !== 'number') throw new KError("Can't negate a " + typeOf(v), n.line);
          return -v;
        }
        case 'Logical': {
          const l = await this.eval(n.left, env);
          if (n.op === 'and') return truthy(l) ? await this.eval(n.right, env) : l;
          return truthy(l) ? l : await this.eval(n.right, env);
        }
        case 'Binary': return this.binop(n.op, await this.eval(n.left, env), await this.eval(n.right, env), n.line);
        case 'Index': {
          const o = await this.eval(n.obj, env), k = await this.eval(n.index, env);
          return getItem(o, k, n.line);
        }
        case 'Member': {
          const o = await this.eval(n.obj, env);
          if (o instanceof KMap) return o.m.has(n.name) ? o.m.get(n.name) : null;
          const hint = { length: 'len(x)', size: 'len(x)', push: 'push(list, item)', append: 'push(list, item)', pop: 'pop(list)', join: 'join(list, sep)', split: 'split(text, sep)', upper: 'upper(text)', lower: 'lower(text)', toUpperCase: 'upper(text)', toLowerCase: 'lower(text)', trim: 'trim(text)', map: 'map(list, fn)', filter: 'filter(list, fn)', keys: 'keys(map)', includes: 'has(x, item)', indexOf: 'indexof(x, item)', replace: 'replace(text, a, b)' }[n.name];
          throw new KError("Can't read field '." + n.name + "' of a " + typeOf(o) + ' (only maps have fields)' + (hint ? ' — use ' + hint + ' instead' : ''), n.line);
        }
        case 'Call': {
          const f = await this.eval(n.callee, env);
          const args = [];
          for (const a of n.args) args.push(await this.eval(a, env));
          await this.step(n.line);
          return this.callValue(f, args, n.line, n.callee.name);
        }
      }
      throw new KError('Unknown expression ' + n.type, n.line);
    }
    async callValue(f, args, line, nameHint) {
      if (f instanceof KBuiltin) {
        if (args.length < f.min || args.length > f.max) {
          const want = f.min === f.max ? f.min : f.max === Infinity ? 'at least ' + f.min : f.min + '-' + f.max;
          throw new KError(f.name + '() expects ' + want + ' argument' + (want === 1 ? '' : 's') + ', got ' + args.length, line);
        }
        if (this.hooks && this.hooks.builtin) this.hooks.builtin(f.name, args, line);
        try {
          return await f.fn(args, { line, interp: this, call: (fn, a) => this.callValue(fn, a, line) });
        } catch (e) {
          if (e instanceof KError || e instanceof ReturnSig || e === BREAK || e === CONTINUE) { if (e instanceof KError && !e.line) { e.line = line; e.message = 'Line ' + line + ': ' + e.kmsg; } throw e; }
          throw new KError(f.name + '(): ' + (e && e.message ? e.message : String(e)), line);
        }
      }
      if (f instanceof KFunc) {
        if (args.length > f.params.length) throw new KError((f.name || 'function') + '() takes ' + f.params.length + ' argument' + (f.params.length === 1 ? '' : 's') + ', got ' + args.length, line);
        if (this.depth > 200) throw new KError('Too much recursion (more than 200 nested calls)', line);
        const e = new Env(f.closure);
        f.params.forEach((p, i) => e.define(p, i < args.length ? args[i] : null));
        this.depth++;
        const frame = { name: f.name || 'anonymous fn', line, env: e }; this.callStack.push(frame);
        try { await this.execBlock(f.body, e); }
        catch (x) {
          if (x instanceof ReturnSig) return x.v;
          if (x === BREAK || x === CONTINUE) throw new KError("'break'/'continue' used outside of a loop", line);
          throw x;
        } finally { this.depth--; const i = this.callStack.lastIndexOf(frame); if (i >= 0) this.callStack.splice(i, 1); }
        return null;
      }
      throw new KError((nameHint ? "'" + nameHint + "'" : 'That') + ' is a ' + typeOf(f) + ', not a function', line);
    }
  }
  function eq(a, b) {
    if (a === b) return true;
    if (Array.isArray(a) && Array.isArray(b)) return a.length === b.length && a.every((x, i) => eq(x, b[i]));
    return false;
  }
  function getItem(o, k, line) {
    if (Array.isArray(o) || typeof o === 'string') {
      if (typeof k !== 'number') throw new KError('Index must be a number, got ' + typeOf(k), line);
      let i = Math.floor(k); if (i < 0) i += o.length;
      if (i < 0 || i >= o.length) throw new KError('Index ' + k + ' is out of range (length ' + o.length + ')', line);
      return o[i];
    }
    if (o instanceof KMap) { const s = String(k); return o.m.has(s) ? o.m.get(s) : null; }
    throw new KError("Can't index into a " + typeOf(o), line);
  }

  // ------------------------------------------------------------ Core constants (v1.3)
  const CONSTANTS = { PI: Math.PI, TAU: Math.PI * 2, E: Math.E, INFINITY: Infinity };
  // ------------------------------------------------------------ Core builtins
  function need(cond, msg) { if (!cond) throw new KError(msg); }
  function vecOf(v, nm) { need(v instanceof KMap && typeof v.m.get('x') === 'number' && typeof v.m.get('y') === 'number', nm + ' needs a vector like vec(1, 2) or {x: 1, y: 2}, got ' + show(v)); return v; }
  function hexRGB(c, nm) {
    let s = typeof c === 'string' ? c.trim() : ''; need(/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(s), nm + ' needs a color like "#ff4500", got ' + show(c));
    if (s.length === 4) s = '#' + s[1] + s[1] + s[2] + s[2] + s[3] + s[3]; const n = parseInt(s.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  const toHex = (r, g, b) => '#' + [r, g, b].map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
  function coreBuiltins() {
    const B = (fn, min, max) => ({ fn, min, max });
    const str = (v, nm) => { need(typeof v === 'string', nm + ' needs a string, got ' + typeOf(v)); return v; };
    const num = (v, nm) => { need(typeof v === 'number', nm + ' needs a number, got ' + typeOf(v)); return v; };
    const list = (v, nm) => { need(Array.isArray(v), nm + ' needs a list, got ' + typeOf(v)); return v; };
    return {
      print: B((a, c) => { c.interp.print(a.map(x => show(x)).join(' ')); return null; }, 0),
      input: B(async (a, c) => {
        const f = c.interp.opts.onInput; need(f, 'input() is not available here');
        const r = await f(a.length ? show(a[0]) : ''); return r === null || r === undefined ? '' : String(r);
      }, 0, 1),
      len: B(([v]) => { if (typeof v === 'string' || Array.isArray(v)) return v.length; if (v instanceof KMap) return v.m.size; throw new KError('len() needs a string, list or map, got ' + typeOf(v)); }, 1, 1),
      str: B(([v]) => show(v), 1, 1),
      num: B(([v]) => { if (typeof v === 'number') return v; const n = parseFloat(String(v)); return isNaN(n) ? null : n; }, 1, 1),
      type: B(([v]) => typeOf(v), 1, 1),
      floor: B(([v]) => Math.floor(num(v, 'floor()')), 1, 1),
      ceil: B(([v]) => Math.ceil(num(v, 'ceil()')), 1, 1),
      round: B(([v, d]) => { num(v, 'round()'); const f = Math.pow(10, d || 0); return Math.round(v * f) / f; }, 1, 2),
      abs: B(([v]) => Math.abs(num(v, 'abs()')), 1, 1),
      sqrt: B(([v]) => { num(v, 'sqrt()'); need(v >= 0, "sqrt() of a negative number"); return Math.sqrt(v); }, 1, 1),
      pow: B(([a, b]) => Math.pow(num(a, 'pow()'), num(b, 'pow()')), 2, 2),
      sin: B(([v]) => Math.sin(num(v, 'sin()')), 1, 1),
      cos: B(([v]) => Math.cos(num(v, 'cos()')), 1, 1),
      min: B((a) => { const xs = a.length === 1 && Array.isArray(a[0]) ? a[0] : a; need(xs.length, 'min() of nothing'); return Math.min(...xs.map(x => num(x, 'min()'))); }, 1),
      max: B((a) => { const xs = a.length === 1 && Array.isArray(a[0]) ? a[0] : a; need(xs.length, 'max() of nothing'); return Math.max(...xs.map(x => num(x, 'max()'))); }, 1),
      random: B((a) => { if (!a.length) return Math.random(); const lo = num(a[0], 'random()'), hi = num(a[1], 'random()'); return lo + Math.floor(Math.random() * (hi - lo + 1)); }, 0, 2),
      range: B((a) => {
        let s = 0, e, st = 1;
        if (a.length === 1) e = num(a[0], 'range()'); else { s = num(a[0], 'range()'); e = num(a[1], 'range()'); if (a.length > 2) st = num(a[2], 'range()'); }
        need(st !== 0, 'range() step cannot be 0');
        const out = []; for (let i = s; st > 0 ? i < e : i > e; i += st) { out.push(i); if (out.length > 1e6) throw new KError('range() too big'); } return out;
      }, 1, 3),
      push: B(([l, v]) => { list(l, 'push()').push(v); return l; }, 2, 2),
      pop: B(([l]) => { list(l, 'pop()'); need(l.length, 'pop() from an empty list'); return l.pop(); }, 1, 1),
      insert: B(([l, i, v]) => { list(l, 'insert()').splice(num(i, 'insert()'), 0, v); return l; }, 3, 3),
      remove: B(([l, i]) => {
        if (l instanceof KMap) { const k = String(i); const v = l.m.get(k); l.m.delete(k); return v === undefined ? null : v; }
        list(l, 'remove()'); let j = num(i, 'remove()'); if (j < 0) j += l.length; need(j >= 0 && j < l.length, 'remove() index out of range'); return l.splice(j, 1)[0];
      }, 2, 2),
      keys: B(([m]) => { need(m instanceof KMap, 'keys() needs a map'); return [...m.m.keys()]; }, 1, 1),
      values: B(([m]) => { need(m instanceof KMap, 'values() needs a map'); return [...m.m.values()]; }, 1, 1),
      has: B(([c, x]) => {
        if (c instanceof KMap) return c.m.has(String(x));
        if (Array.isArray(c)) return c.some(y => eq(y, x));
        if (typeof c === 'string') return c.includes(show(x));
        throw new KError('has() needs a map, list or string');
      }, 2, 2),
      contains: B(([s, x]) => Array.isArray(s) ? s.some(y => eq(y, x)) : str(s, 'contains()').includes(show(x)), 2, 2),
      indexof: B(([s, x]) => Array.isArray(s) ? s.findIndex(y => eq(y, x)) : str(s, 'indexof()').indexOf(show(x)), 2, 2),
      upper: B(([s]) => str(s, 'upper()').toUpperCase(), 1, 1),
      lower: B(([s]) => str(s, 'lower()').toLowerCase(), 1, 1),
      trim: B(([s]) => str(s, 'trim()').trim(), 1, 1),
      split: B(([s, sep]) => str(s, 'split()').split(sep === undefined ? ' ' : show(sep)), 1, 2),
      join: B(([l, sep]) => list(l, 'join()').map(x => show(x)).join(sep === undefined ? '' : show(sep)), 1, 2),
      replace: B(([s, a, b]) => str(s, 'replace()').split(show(a)).join(show(b)), 3, 3),
      startswith: B(([s, x]) => str(s, 'startswith()').startsWith(show(x)), 2, 2),
      endswith: B(([s, x]) => str(s, 'endswith()').endsWith(show(x)), 2, 2),
      substr: B(([s, a, n]) => str(s, 'substr()').substr(num(a, 'substr()'), n === undefined ? undefined : n), 2, 3),
      slice: B(([s, a, b]) => { need(typeof s === 'string' || Array.isArray(s), 'slice() needs a string or list'); return s.slice(a === undefined ? 0 : a, b === undefined ? undefined : b); }, 1, 3),
      chr: B(([n]) => String.fromCharCode(num(n, 'chr()')), 1, 1),
      ord: B(([s]) => str(s, 'ord()').charCodeAt(0) || 0, 1, 1),
      sort: B(([l]) => list(l, 'sort()').slice().sort((a, b) => (typeof a === 'number' && typeof b === 'number') ? a - b : show(a) < show(b) ? -1 : show(a) > show(b) ? 1 : 0), 1, 1),
      reverse: B(([l]) => typeof l === 'string' ? [...l].reverse().join('') : list(l, 'reverse()').slice().reverse(), 1, 1),
      map: B(async ([l, f], c) => { list(l, 'map()'); const out = []; for (const x of l) out.push(await c.call(f, [x])); return out; }, 2, 2),
      filter: B(async ([l, f], c) => { list(l, 'filter()'); const out = []; for (const x of l) if (truthy(await c.call(f, [x]))) out.push(x); return out; }, 2, 2),
      time: B(() => Date.now(), 0, 0),
      sleep: B(async ([ms], c) => { num(ms, 'sleep()'); const end = Date.now() + Math.min(ms, 60000); while (Date.now() < end) { if (c.interp.stopped) throw new KError('Program stopped.'); await new Promise(r => setTimeout(r, Math.min(50, end - Date.now()))); } return null; }, 1, 1),
      error: B(([m]) => { throw new KError(show(m)); }, 1, 1),
      // ---- v1.3 math for games & simulations
      tan: B(([v]) => Math.tan(num(v, 'tan()')), 1, 1),
      asin: B(([v]) => Math.asin(num(v, 'asin()')), 1, 1),
      acos: B(([v]) => Math.acos(num(v, 'acos()')), 1, 1),
      atan: B(([v]) => Math.atan(num(v, 'atan()')), 1, 1),
      atan2: B(([y, x]) => Math.atan2(num(y, 'atan2()'), num(x, 'atan2()')), 2, 2),
      exp: B(([v]) => Math.exp(num(v, 'exp()')), 1, 1),
      log: B(([v, b]) => { num(v, 'log()'); need(v > 0, 'log() needs a number above 0'); return b === undefined ? Math.log(v) : Math.log(v) / Math.log(num(b, 'log()')); }, 1, 2),
      hypot: B((a) => Math.hypot(...a.map(x => num(x, 'hypot()'))), 1),
      sign: B(([v]) => Math.sign(num(v, 'sign()')), 1, 1),
      clamp: B(([v, lo, hi]) => Math.min(num(hi, 'clamp()'), Math.max(num(lo, 'clamp()'), num(v, 'clamp()'))), 3, 3),
      lerp: B(([a, b, t]) => num(a, 'lerp()') + (num(b, 'lerp()') - a) * num(t, 'lerp()'), 3, 3),
      random_float: B(([lo, hi]) => { const a = lo === undefined ? 0 : num(lo, 'random_float()'), b = hi === undefined ? 1 : num(hi, 'random_float()'); return a + Math.random() * (b - a); }, 0, 2),
      fmt: B(([v, d]) => { num(v, 'fmt()'); const n = d === undefined ? 0 : Math.max(0, Math.min(10, Math.floor(num(d, 'fmt()')))); return isFinite(v) ? v.toLocaleString('en-US', { minimumFractionDigits: n, maximumFractionDigits: n }) : fmtNum(v); }, 1, 2),
      sum: B(([l]) => list(l, 'sum()').reduce((a, x) => a + num(x, 'sum()'), 0), 1, 1),
      // 2D vectors are plain maps {x, y}
      vec: B(([x, y]) => new KMap({ x: x === undefined ? 0 : num(x, 'vec()'), y: y === undefined ? 0 : num(y, 'vec()') }), 0, 2),
      vadd: B(([a, b]) => { vecOf(a, 'vadd()'); vecOf(b, 'vadd()'); return new KMap({ x: a.m.get('x') + b.m.get('x'), y: a.m.get('y') + b.m.get('y') }); }, 2, 2),
      vsub: B(([a, b]) => { vecOf(a, 'vsub()'); vecOf(b, 'vsub()'); return new KMap({ x: a.m.get('x') - b.m.get('x'), y: a.m.get('y') - b.m.get('y') }); }, 2, 2),
      vmul: B(([a, k]) => { vecOf(a, 'vmul()'); num(k, 'vmul()'); return new KMap({ x: a.m.get('x') * k, y: a.m.get('y') * k }); }, 2, 2),
      vlen: B(([a]) => { vecOf(a, 'vlen()'); return Math.hypot(a.m.get('x'), a.m.get('y')); }, 1, 1),
      vdist: B(([a, b]) => { vecOf(a, 'vdist()'); vecOf(b, 'vdist()'); return Math.hypot(a.m.get('x') - b.m.get('x'), a.m.get('y') - b.m.get('y')); }, 2, 2),
      vdot: B(([a, b]) => { vecOf(a, 'vdot()'); vecOf(b, 'vdot()'); return a.m.get('x') * b.m.get('x') + a.m.get('y') * b.m.get('y'); }, 2, 2),
      vnorm: B(([a]) => { vecOf(a, 'vnorm()'); const l = Math.hypot(a.m.get('x'), a.m.get('y')) || 1; return new KMap({ x: a.m.get('x') / l, y: a.m.get('y') / l }); }, 1, 1),
      vrot: B(([a, r]) => { vecOf(a, 'vrot()'); num(r, 'vrot()'); const c = Math.cos(r), s = Math.sin(r), x = a.m.get('x'), y = a.m.get('y'); return new KMap({ x: x * c - y * s, y: x * s + y * c }); }, 2, 2),
      // colors: "#rrggbb" helpers for themes and shading
      shade: B(([c, amt]) => { const [r, g, b] = hexRGB(c, 'shade()'); const a = num(amt, 'shade()'); const f = (v) => a >= 0 ? v + (255 - v) * a : v * (1 + a); return toHex(f(r), f(g), f(b)); }, 2, 2),
      mix: B(([c1, c2, t]) => { const A = hexRGB(c1, 'mix()'), Bc = hexRGB(c2, 'mix()'), k = num(t, 'mix()'); return toHex(A[0] + (Bc[0] - A[0]) * k, A[1] + (Bc[1] - A[1]) * k, A[2] + (Bc[2] - A[2]) * k); }, 3, 3),
      rgb: B(([r, g, b, a]) => { const c = (v) => Math.max(0, Math.min(255, Math.round(num(v, 'rgb()')))); return a === undefined ? 'rgb(' + c(r) + ',' + c(g) + ',' + c(b) + ')' : 'rgba(' + c(r) + ',' + c(g) + ',' + c(b) + ',' + Math.max(0, Math.min(1, num(a, 'rgb()'))) + ')'; }, 3, 4),
      vangle: B(([a]) => { vecOf(a, 'vangle()'); return Math.atan2(a.m.get('y'), a.m.get('x')); }, 1, 1),
    };
  }

  const api = { tokenize, parse, Interpreter, Env, KError, KMap, KFunc, KBuiltin, KHandle, show, typeOf, truthy, OUT_OF_COINS, KEYWORDS, CONSTANTS };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.KampfScript = api;
})(typeof window !== 'undefined' ? window : this);
