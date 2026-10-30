// Run: node tests/lang.test.js
const K = require('../src/lang.js');
const assert = require('assert');
let pass = 0, fail = 0;
async function run(src, opts = {}) {
  const out = [];
  let wallet = opts.wallet === undefined ? 1000 : opts.wallet;
  const it = new K.Interpreter(Object.assign({
    onPrint: s => out.push(s),
    onCharge: n => { if (wallet < n) return false; wallet -= n; return true; },
    onInput: async p => opts.input || 'Kampf',
  }, opts));
  const r = await it.run(src);
  return { out, r, wallet, it };
}
async function t(name, fn) {
  try { await fn(); pass++; console.log('  ok  ', name); }
  catch (e) { fail++; console.log('  FAIL', name, '\n       ', e.message); }
}
(async () => {
  await t('hello + math precedence', async () => {
    const { out } = await run('print("Hello", 1 + 2 * 3)\nprint((1+2)*3, 7 % 3, 10 / 4)');
    assert.deepStrictEqual(out, ['Hello 7', '9 1 2.5']);
  });
  await t('variables, strings, concat', async () => {
    const { out } = await run('let name = "Kampf"\nlet n = 3\nprint("hi " + name + " x" + n)\nprint(upper(name), len(name), "ab" * 3)');
    assert.deepStrictEqual(out, ['hi Kampf x3', 'KAMPF 5 ababab']);
  });
  await t('while + for loops, break/continue', async () => {
    const { out } = await run(`
let total = 0
for i in range(1, 101) { total += i }
print(total)
let i = 0
while true {
  i += 1
  if i % 2 == 0 { continue }
  if i > 7 { break }
  print(i)
}`);
    assert.deepStrictEqual(out, ['5050', '1', '3', '5', '7']);
  });
  await t('if / else if / else', async () => {
    const { out } = await run(`
fn grade(s) {
  if s >= 90 { return "A" }
  else if s >= 80 { return "B" }
  else { return "C" }
}
print(grade(95), grade(85), grade(10))`);
    assert.deepStrictEqual(out, ['A B C']);
  });
  await t('recursion + closures', async () => {
    const { out } = await run(`
fn fib(n) { if n < 2 { return n } return fib(n-1) + fib(n-2) }
print(fib(15))
fn counter() {
  let c = 0
  return fn() { c += 1
    return c }
}
let next = counter()
next()
next()
print(next())`);
    assert.deepStrictEqual(out, ['610', '3']);
  });
  await t('lists, maps, member access, higher-order', async () => {
    const { out } = await run(`
let xs = [3, 1, 2]
push(xs, 10)
xs[0] = 5
let m = {name: "Kugel", "hits": 2}
m.hits += 1
m["new"] = true
print(xs, sort(xs), len(xs), xs[-1])
print(m.name, m.hits, m.missing, keys(m))
print(map(xs, fn(x) { return x * 2 }), filter(xs, fn(x) { return x > 2 }))
print(join(split("a,b,c", ","), "-"), contains("hello", "ell"), replace("aXbX", "X", "."))`);
    assert.deepStrictEqual(out, ['[5, 1, 2, 10] [1, 2, 5, 10] 4 10', 'Kugel 3 nil ["name", "hits", "new"]', '[10, 2, 4, 20] [5, 10]', 'a-b-c true a.b.']);
  });
  await t('loop closures capture per-iteration value', async () => {
    const { out } = await run('let fs = []\nfor i in range(3) { push(fs, fn() { return i }) }\nprint(fs[0](), fs[2]())');
    assert.deepStrictEqual(out, ['0 2']);
  });
  await t('input()', async () => {
    const { out } = await run('let n = input("Name?")\nprint("Hi " + n)', { input: 'Bob' });
    assert.deepStrictEqual(out, ['Hi Bob']);
  });
  const errCase = async (src, re, line) => {
    try { await run(src); } catch (e) { assert(e instanceof K.KError, 'not KError: ' + e); assert.match(e.message, re); if (line) assert.strictEqual(e.line, line); return e; }
    throw new Error('expected error ' + re);
  };
  await t('error: unknown variable w/ line', () => errCase('let a = 1\nprint(b)', /Line 2: Unknown name 'b'/, 2));
  await t('error: unterminated string', () => errCase('print("oops)', /Line 1: Unterminated string/, 1));
  await t('error: missing }', () => errCase('if true {\n print(1)\n', /Missing '}'/));
  await t('error: type error', () => errCase('let x = [1]\n\nlet y = x - 1', /Line 3: Can't use '-' on list and number/, 3));
  await t('error: division by zero', () => errCase('print(1/0)', /Division by zero/));
  await t('error: index out of range', () => errCase('let l = [1,2]\nprint(l[5])', /Line 2: Index 5 is out of range/, 2));
  await t('error: calling a non-function', () => errCase('let x = 3\nx()', /'x' is a number, not a function/));
  await t('error: wrong builtin arity', () => errCase('print(len())', /len\(\) expects 1 argument, got 0/));
  await t('error: bad syntax', () => errCase('let = 5', /Line 1: Expected a variable name/));
  await t('error: deep recursion', () => errCase('fn f(n) { return f(n+1) }\nf(0)', /Too much recursion/));
  await t('metering: step limit stops infinite loop', async () => {
    try { await run('while true { let a = 1 }', { maxSteps: 5000 }); assert.fail('no error'); }
    catch (e) { assert.match(e.message, /Step limit reached \(5000 steps\)/); assert.strictEqual(e.code, 'STEP_LIMIT'); }
  });
  await t('metering: run cost + 1 coin per N steps', async () => {
    const { r, wallet } = await run('for i in range(1000) { let x = i * 2 }', { runCost: 5, stepsPerCoin: 500, wallet: 100 });
    assert(r.steps > 2000, 'steps ' + r.steps);
    assert.strictEqual(100 - wallet, 5 + Math.floor(r.steps / 500));
  });
  await t('metering: out of coins aborts', async () => {
    try { await run('for i in range(100000) { let x = i }', { runCost: 2, stepsPerCoin: 100, wallet: 5, maxSteps: 1e6 }); assert.fail('no error'); }
    catch (e) { assert.strictEqual(e.code, K.OUT_OF_COINS); assert.match(e.message, /Out of coins/); }
  });
  await t('metering: cannot even start with 0 coins', async () => {
    try { await run('print(1)', { runCost: 3, wallet: 2 }); assert.fail('no error'); }
    catch (e) { assert.strictEqual(e.code, K.OUT_OF_COINS); }
  });
  await t('invoke callback gets fresh budget, errors reported', async () => {
    const errs = [];
    const { it, out } = await run('let cb = fn(x) { print("got " + x) }\nlet bad = fn() { return nope }', { onError: e => errs.push(e.message) });
    await it.invoke(it.globals.get('cb'), ['click']);
    await it.invoke(it.globals.get('bad'), []);
    assert.deepStrictEqual(out, ['got click']);
    assert.match(errs[0], /Line 2: Unknown name 'nope'/);
  });
  const fs = require('fs'), path = require('path');
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(d, e.name)) : e.name.endsWith('.ks') ? [path.join(d, e.name)] : []);
  for (const f of walk(path.join(__dirname, '..', 'resources'))) await t('parses ' + path.relative(path.join(__dirname, '..'), f), async () => { K.parse(fs.readFileSync(f, 'utf8')); });
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
