// Parses the Lua table literals WoW writes into saved variables files.
// Only what that format uses: tables, strings, numbers, true, false, nil,
// ["key"] = value, [n] = value, positional values and -- comments.
//
// A table with only positional values becomes an array (nil becomes null).
// Anything else becomes an object. Numeric keys become string keys.

export function parseSavedVariables(text) {
  let at = 0;
  const end = text.length;

  function skip() {
    for (;;) {
      const c = text.charCodeAt(at);
      if (c === 32 || c === 10 || c === 13 || c === 9 || c === 44 /* , */) {
        at++;
      } else if (c === 45 && text.charCodeAt(at + 1) === 45) {
        const lineEnd = text.indexOf("\n", at);
        at = lineEnd === -1 ? end : lineEnd + 1;
      } else {
        return;
      }
    }
  }

  function parseString() {
    at++; // opening quote
    let out = "";
    let from = at;
    for (;;) {
      const c = text.charCodeAt(at);
      if (c === 34) {
        out += text.slice(from, at);
        at++;
        return out;
      }
      if (c === 92) {
        out += text.slice(from, at);
        const next = text[at + 1];
        if (next === "n") out += "\n";
        else if (next === "r") out += "\r";
        else if (next === "t") out += "\t";
        else if (next >= "0" && next <= "9") {
          const digits = /^\d{1,3}/.exec(text.slice(at + 1, at + 4))[0];
          out += String.fromCharCode(Number(digits));
          at += digits.length - 1;
        } else out += next;
        at += 2;
        from = at;
      } else {
        at++;
      }
      if (at > end) throw new Error("unterminated string");
    }
  }

  function parseBare() {
    const from = at;
    while (at < end) {
      const c = text.charCodeAt(at);
      if (c === 44 || c === 10 || c === 13 || c === 32 || c === 125 || c === 93) break;
      at++;
    }
    const word = text.slice(from, at);
    if (word === "nil") return null;
    if (word === "true") return true;
    if (word === "false") return false;
    const number = Number(word);
    if (Number.isNaN(number)) throw new Error(`unexpected "${word}" at ${from}`);
    return number;
  }

  function parseValue() {
    skip();
    const c = text.charCodeAt(at);
    if (c === 123) return parseTable();
    if (c === 34) return parseString();
    return parseBare();
  }

  function parseTable() {
    at++; // {
    const list = [];
    let keyed = null;
    for (;;) {
      skip();
      const c = text.charCodeAt(at);
      if (c === 125) {
        at++;
        break;
      }
      if (c === 91) {
        at++; // [
        const key = text.charCodeAt(at) === 34 ? parseString() : parseBare();
        skip();
        at++; // ]
        skip();
        at++; // =
        keyed ??= {};
        keyed[key] = parseValue();
      } else {
        list.push(parseValue());
      }
      if (at > end) throw new Error("unterminated table");
    }
    if (!keyed) return list;
    list.forEach((value, index) => {
      keyed[index + 1] = value;
    });
    return keyed;
  }

  // The file is a series of `Name = value` assignments.
  const globals = {};
  for (;;) {
    skip();
    if (at >= end) break;
    const match = /^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*/.exec(text.slice(at, at + 200));
    if (!match) throw new Error(`expected an assignment at ${at}`);
    at += match[0].length;
    globals[match[1]] = parseValue();
  }
  return globals;
}
