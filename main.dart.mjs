// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: x0 => new Int16Array(x0),
      AC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      AD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      AE: x0 => x0.matches,
      AF: x0 => x0.pressure,
      AG: (x0,x1) => x0.querySelectorAll(x1),
      AH: x0 => x0.clipboard,
      AI: x0 => x0.disabled,
      AJ: x0 => x0.headers,
      AK: x0 => x0.repeat,
      B: s => printToConsole(s),
      BB: x0 => new Uint16Array(x0),
      BC: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      BD: x0 => x0.getBoundingClientRect(),
      BE: (x0,x1) => x0.matchMedia(x1),
      BF: x0 => x0.tiltY,
      BG: (x0,x1) => x0.requestAnimationFrame(x1),
      BH: (x0,x1) => x0.writeText(x1),
      BI: (x0,x1) => { x0.min = x1 },
      BJ: x0 => x0.signal,
      BK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      CC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      CD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      CE: x0 => x0.matches,
      CF: x0 => x0.tiltX,
      CG: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CH: x0 => x0.unlock(),
      CI: (x0,x1) => { x0.max = x1 },
      CJ: (x0,x1) => x0.revokeObjectURL(x1),
      CK: (x0,x1) => x0.getItem(x1),
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: x0 => new Int32Array(x0),
      DC: (x0,x1) => x0.querySelector(x1),
      DD: s => new Date(s * 1000).getTimezoneOffset() * 60,
      DE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      DF: x0 => x0.pointerType,
      DG: x0 => x0.now(),
      DH: (x0,x1) => x0.lock(x1),
      DI: (x0,x1) => { x0.disabled = x1 },
      DJ: (x0,x1) => { x0.src = x1 },
      DK: x0 => x0.localStorage,
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      EC: (x0,x1) => x0.item(x1),
      ED: Date.now,
      EE: f => f.dartFunction,
      EF: x0 => x0.pointerId,
      EG: x0 => x0.performance,
      EH: x0 => x0.orientation,
      EI: (x0,x1) => { x0.scrollLeft = x1 },
      EJ: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      EK: () => globalThis.window,
      F: () => new Error().stack,
      FB: x0 => new Uint32Array(x0),
      FC: x0 => x0.length,
      FD: (handle) => clearTimeout(handle),
      FE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      FF: x0 => x0.getCoalescedEvents(),
      FG: (d, digits) => d.toFixed(digits),
      FH: (x0,x1) => x0.querySelector(x1),
      FI: (x0,x1) => { x0.spellcheck = x1 },
      FJ: x0 => x0.naturalHeight,
      FK: (x0,x1) => x0.key(x1),
      G: s => JSON.stringify(s),
      GB: x0 => new Float32Array(x0),
      GC: (x0,x1) => x0.querySelectorAll(x1),
      GD: (x0,x1) => x0.closest(x1),
      GE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      GF: (x0,x1) => x0.getModifierState(x1),
      GG: x0 => x0.maxHeight,
      GH: (x0,x1) => { x0.title = x1 },
      GI: (x0,x1) => { x0.disabled = x1 },
      GJ: x0 => x0.naturalWidth,
      GK: x0 => x0.length,
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      HC: (x0,x1) => x0.getAttribute(x1),
      HD: x0 => x0.bottom,
      HE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      HF: s => s.trimLeft(),
      HG: x0 => x0.maxWidth,
      HH: (x0,x1) => x0.vibrate(x1),
      HI: (a, i) => a.splice(i, 1),
      HJ: x0 => x0.decode(),
      HK: (x0,x1,x2) => x0.setItem(x1,x2),
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Float64Array(x0),
      IC: x0 => x0.remove(),
      ID: x0 => x0.top,
      IE: (o, i) => o[i],
      IF: (x0,x1) => x0[x1],
      IG: x0 => x0.minHeight,
      IH: x0 => x0.arrayBuffer(),
      II: a => a.pop(),
      IJ: (x0,x1) => { x0.decoding = x1 },
      IK: (x0,x1) => x0.query(x1),
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      JC: (x0,x1) => x0.appendChild(x1),
      JD: x0 => x0.right,
      JE: o => o.length,
      JF: x0 => x0.index,
      JG: x0 => x0.minWidth,
      JH: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      JI: (map, o, v) => map.set(o, v),
      JJ: (x0,x1) => { x0.crossOrigin = x1 },
      JK: x0 => x0.state,
      K: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      KB: x0 => new ArrayBuffer(x0),
      KC: (x0,x1) => x0.append(x1),
      KD: x0 => x0.left,
      KE: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      KF: (x0,x1) => x0.exec(x1),
      KG: (x0,x1) => x0.removeProperty(x1),
      KH: x0 => x0.status,
      KI: (map, o) => map.get(o),
      KJ: (x0,x1) => x0.createObjectURL(x1),
      KK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      L: o => o === undefined,
      LB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      LC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      LD: x0 => x0.clientY,
      LE: x0 => x0.language,
      LF: s => s.toUpperCase(),
      LG: (x0,x1) => x0.add(x1),
      LH: (x0,x1) => x0.fetch(x1),
      LI: () => new WeakMap(),
      LJ: x0 => x0.URL,
      LK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      M: o => String(o),
      MB: (x0,x1,x2) => new DataView(x0,x1,x2),
      MC: x0 => x0.style,
      MD: x0 => x0.clientX,
      ME: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      MF: (x0,x1) => x0.test(x1),
      MG: x0 => x0.data,
      MH: x0 => x0.content,
      MI: x0 => new WeakRef(x0),
      MJ: x0 => new Blob(x0),
      MK: (x0,x1,x2) => ({enableHighAccuracy: x0,timeout: x1,maximumAge: x2}),
      N: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      NB: (o, p) => o[p],
      NC: x0 => x0.debugShowSemanticsNodes,
      ND: x0 => x0.changedTouches,
      NE: () => globalThis.window.FinalizationRegistry,
      NF: x0 => x0.length,
      NG: (x0,x1) => { x0.scrollTop = x1 },
      NH: x0 => x0.document,
      NI: x0 => x0.deref(),
      NJ: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      NK: (x0,x1,x2,x3) => x0.getCurrentPosition(x1,x2,x3),
      O: (x0,x1) => x0.didCreateEngineInitializer(x1),
      OB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      OC: o => o,
      OD: x0 => x0.offsetY,
      OE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      OF: x0 => x0.flags,
      OG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      OH: () => typeof dartUseDateNowForTicks !== "undefined",
      OI: () => globalThis.WeakRef,
      OJ: x0 => new window.ImageDecoder(x0),
      OK: x0 => x0.message,
      P: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      PC: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      PD: x0 => x0.offsetX,
      PE: x0 => new window.FinalizationRegistry(x0),
      PF: (a, s) => a.join(s),
      PG: (x0,x1) => { x0.value = x1 },
      PH: () => Date.now(),
      PI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      PJ: x0 => x0.name,
      PK: x0 => x0.code,
      Q: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      QB: o => o.byteOffset,
      QC: (x0,x1) => x0.warn(x1),
      QD: x0 => x0.type,
      QE: (x0,x1) => x0.unregister(x1),
      QF: (x0,x1) => x0.error(x1),
      QG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      QH: () => 1000 * performance.now(),
      QI: (a, s, e) => a.slice(s, e),
      QJ: x0 => x0.repetitionCount,
      QK: x0 => x0.speed,
      R: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      RB: o => o.buffer,
      RC: x0 => x0.console,
      RD: x0 => x0.maxTouchPoints,
      RE: (x0,x1) => x0.contains(x1),
      RF: () => globalThis.console,
      RG: (x0,x1) => { x0.value = x1 },
      RH: x0 => new Uint8Array(x0),
      RI: (x0,x1) => x0.send(x1),
      RJ: x0 => x0.frameCount,
      RK: x0 => x0.heading,
      S: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      SB: Function.prototype.call.bind(DataView.prototype.getUint8),
      SC: () => globalThis.window,
      SD: x0 => x0.platform,
      SE: (s) => +s,
      SF: s => s.trimRight(),
      SG: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      SH: (x0,x1,x2) => x0.slice(x1,x2),
      SI: x0 => globalThis.window.crypto.getRandomValues(x0),
      SJ: x0 => x0.selectedTrack,
      SK: x0 => x0.accuracy,
      T: x0 => new Promise(x0),
      TB: (b, o) => new DataView(b, o),
      TC: (o, c) => o instanceof c,
      TD: x0 => x0.body,
      TE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      TF: x0 => x0.blur(),
      TG: x0 => x0.value,
      TH: (x0,x1) => x0.decode(x1),
      TI: (x0,x1) => x0.getRandomValues(x1),
      TJ: x0 => x0.completed,
      TK: x0 => x0.altitudeAccuracy,
      U: (x0,x1,x2) => x0.call(x1,x2),
      UB: (b, o, l) => new DataView(b, o, l),
      UC: (string, token) => string.split(token),
      UD: () => globalThis.document,
      UE: s => s.trim(),
      UF: x0 => x0.button,
      UG: x0 => x0.selectionDirection,
      UH: (x0,x1) => x0.adoptText(x1),
      UI: () => globalThis.crypto,
      UJ: x0 => x0.ready,
      UK: x0 => x0.altitude,
      V: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      VB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      VC: o => o instanceof Array,
      VD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      VE: x0 => x0.classList,
      VF: x0 => x0.innerHeight,
      VG: x0 => x0.selectionStart,
      VH: x0 => x0.first(),
      VI: l => new DataView(new ArrayBuffer(l)),
      VJ: x0 => x0.tracks,
      VK: x0 => x0.timestamp,
      W: x0 => new Array(x0),
      WB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      WC: (a, i) => a[i],
      WD: x0 => x0.hasFocus(),
      WE: x0 => x0.preventDefault(),
      WF: x0 => x0.innerWidth,
      WG: x0 => x0.selectionEnd,
      WH: x0 => x0.next(),
      WI: () => globalThis.window.isSecureContext,
      WJ: x0 => x0.close(),
      WK: x0 => x0.longitude,
      X: o => [o],
      XB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      XC: a => a.length,
      XD: x0 => x0.relatedTarget,
      XE: x0 => x0.parent,
      XF: x0 => x0.height,
      XG: x0 => x0.value,
      XH: x0 => x0.current(),
      XI: () => globalThis.crypto.subtle,
      XJ: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      XK: x0 => x0.latitude,
      Y: (o0, o1) => [o0, o1],
      YB: (t, s) => t.set(s),
      YC: x0 => x0.userAgent,
      YD: x0 => x0.shiftKey,
      YE: x0 => x0.timeStamp,
      YF: x0 => x0.width,
      YG: x0 => x0.selectionDirection,
      YH: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      YI: x0 => x0.pop(),
      YJ: (x0,x1) => x0.decode(x1),
      YK: x0 => x0.coords,
      Z: (o0, o1, o2) => [o0, o1, o2],
      ZB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      ZC: x0 => x0.navigator,
      ZD: (decoder, codeUnits) => decoder.decode(codeUnits),
      ZE: (x0,x1) => x0.hasAttribute(x1),
      ZF: x0 => x0.clientHeight,
      ZG: x0 => x0.selectionStart,
      ZH: x0 => x0.v8BreakIterator,
      ZI: x0 => x0.close(),
      ZJ: x0 => x0.displayHeight,
      ZK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      a: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      aB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      aC: Function.prototype.call.bind(String.prototype.toLowerCase),
      aD: () => new TextDecoder("utf-8", {fatal: true}),
      aE: x0 => x0.buttons,
      aF: x0 => x0.clientWidth,
      aG: x0 => x0.selectionEnd,
      aH: () => globalThis.Intl,
      aI: (x0,x1) => new WebSocket(x0,x1),
      aJ: x0 => x0.displayWidth,
      aK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      b: (x0,x1,x2) => { x0[x1] = x2 },
      bB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      bC: Object.is,
      bD: () => new TextDecoder("utf-8", {fatal: false}),
      bE: x0 => x0.ctrlKey,
      bF: (x0,x1) => { x0.content = x1 },
      bG: x0 => x0.keyCode,
      bH: (x0,x1) => x0.segment(x1),
      bI: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      bJ: x0 => x0.duration,
      bK: (x0,x1,x2,x3) => x0.watchPosition(x1,x2,x3),
      c: o => o,
      cB: Function.prototype.call.bind(DataView.prototype.getUint32),
      cC: x0 => x0.vendor,
      cD: (a, i, v) => a[i] = v,
      cE: x0 => x0.y,
      cF: (x0,x1) => { x0.name = x1 },
      cG: (x0,x1) => x0.scrollIntoView(x1),
      cH: x0 => x0.index,
      cI: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      cJ: x0 => x0.image,
      cK: (x0,x1) => x0.clearWatch(x1),
      d: (o, p) => o[p],
      dB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      dC: (x0,x1) => x0.createTextNode(x1),
      dD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      dE: x0 => x0.x,
      dF: x0 => x0.head,
      dG: x0 => x0.multiViewEnabled,
      dH: x0 => x0.next(),
      dI: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      dJ: () => globalThis.window.ImageDecoder,
      dK: x0 => x0.permissions,
      e: () => globalThis,
      eB: Function.prototype.call.bind(DataView.prototype.getInt32),
      eC: (x0,x1) => { x0.id = x1 },
      eD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      eE: x0 => x0.scrollTop,
      eF: (x0,x1) => x0.removeChild(x1),
      eG: (x0,x1) => x0.replaceWith(x1),
      eH: x0 => x0.value,
      eI: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eJ: x0 => x0.abort(),
      eK: x0 => x0.navigator,
      f: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      fC: (x0,x1) => { x0.nonce = x1 },
      fD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      fE: x0 => x0.offsetTop,
      fF: x0 => x0.firstChild,
      fG: (x0,x1) => { x0.type = x1 },
      fH: x0 => x0.done,
      fI: x0 => x0.data,
      fJ: (x0,x1,x2,x3) => ({name: x0,iv: x1,additionalData: x2,tagLength: x3}),
      fK: x0 => x0.geolocation,
      g: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gB: o => o instanceof Uint16Array,
      gC: x0 => x0.nonce,
      gD: x0 => x0.visibilityState,
      gE: x0 => x0.scrollLeft,
      gF: x0 => x0.viewConstraints,
      gG: (x0,x1) => { x0.className = x1 },
      gH: (o, m, a) => o[m].apply(o, a),
      gI: (x0,x1) => { x0.binaryType = x1 },
      gJ: (x0,x1,x2) => globalThis.crypto.subtle.decrypt(x0,x1,x2),
      gK: x0 => x0.length,
      h: (x0,x1) => ({addView: x0,removeView: x1}),
      hB: Function.prototype.call.bind(DataView.prototype.getUint16),
      hC: () => globalThis.window.flutterConfiguration,
      hD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      hE: x0 => x0.offsetLeft,
      hF: x0 => x0.hostElement,
      hG: (x0,x1) => { x0.tabIndex = x1 },
      hH: x0 => x0.iterator,
      hI: (x0,x1,x2,x3) => ({name: x0,hash: x1,salt: x2,iterations: x3}),
      hJ: (x0,x1,x2) => globalThis.crypto.subtle.encrypt(x0,x1,x2),
      hK: x0 => x0.getReader(),
      i: (l, r) => l === r,
      iB: o => o instanceof Int16Array,
      iC: (x0,x1) => x0.attachShadow(x1),
      iD: x0 => x0.disconnect(),
      iE: x0 => x0.offsetParent,
      iF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iG: (x0,x1) => { x0.name = x1 },
      iH: () => globalThis.Symbol,
      iI: (x0,x1,x2) => globalThis.crypto.subtle.deriveBits(x0,x1,x2),
      iJ: (x0,x1) => x0.transferFromImageBitmap(x1),
      iK: x0 => x0.value,
      j: x0 => x0.random(),
      jB: Function.prototype.call.bind(DataView.prototype.getInt16),
      jC: (x0,x1) => x0.createElement(x1),
      jD: x0 => new Intl.Locale(x0),
      jE: (o, p, r) => o.replace(p, () => r),
      jF: x0 => ({runApp: x0}),
      jG: (x0,x1) => { x0.placeholder = x1 },
      jH: (x0,x1) => new Intl.Segmenter(x0,x1),
      jI: (x0,x1,x2,x3,x4) => globalThis.crypto.subtle.importKey(x0,x1,x2,x3,x4),
      jJ: (x0,x1) => x0.getContext(x1),
      jK: x0 => x0.done,
      k: o => o,
      kB: o => o instanceof Uint8ClampedArray,
      kC: x0 => x0.scale,
      kD: x0 => x0.region,
      kE: (x0,x1) => { x0.lastIndex = x1 },
      kF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      kG: (x0,x1) => { x0.autocomplete = x1 },
      kH: x0 => x0.Segmenter,
      kI: () => new AbortController(),
      kJ: (x0,x1) => { x0.height = x1 },
      kK: x0 => x0.read(),
      l: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      lB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      lC: x0 => x0.visualViewport,
      lD: x0 => x0.script,
      lE: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      lF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      lG: (x0,x1) => { x0.name = x1 },
      lH: x0 => x0.buffer,
      lI: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      lJ: (x0,x1) => { x0.width = x1 },
      lK: x0 => x0.body,
      m: () => globalThis.Math,
      mB: Function.prototype.call.bind(DataView.prototype.setInt32),
      mC: x0 => x0.devicePixelRatio,
      mD: x0 => x0.language,
      mE: o => o instanceof RegExp,
      mF: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      mG: (x0,x1) => { x0.placeholder = x1 },
      mH: x0 => x0.wasmMemory,
      mI: (x0,x1) => globalThis.fetch(x0,x1),
      mJ: x0 => x0.height,
      mK: (x0,x1) => new OffscreenCanvas(x0,x1),
      n: (x0,x1) => x0.prepend(x1),
      nB: Function.prototype.call.bind(DataView.prototype.setUint32),
      nC: x0 => x0.height,
      nD: x0 => x0.languages,
      nE: x0 => x0.dotAll,
      nF: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      nG: (x0,x1) => { x0.action = x1 },
      nH: () => globalThis.window._flutter_skwasmInstance,
      nI: (x0,x1) => x0.get(x1),
      nJ: x0 => x0.width,
      nK: x0 => x0.assetBase,
      o: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      oB: Function.prototype.call.bind(DataView.prototype.setInt16),
      oC: x0 => x0.width,
      oD: (x0,x1) => x0.observe(x1),
      oE: x0 => x0.unicode,
      oF: x0 => x0.history,
      oG: (x0,x1) => { x0.method = x1 },
      oH: () => new TextDecoder(),
      oI: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      oJ: x0 => x0.rasterEndMilliseconds,
      oK: x0 => x0.loader,
      p: b => !!b,
      pB: Function.prototype.call.bind(DataView.prototype.setUint16),
      pC: x0 => x0.screen,
      pD: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      pE: x0 => x0.ignoreCase,
      pF: x0 => x0.search,
      pG: (x0,x1) => { x0.noValidate = x1 },
      pH: x0 => x0.debugSkipFontRetryDelay,
      pI: (x0,x1) => x0.forEach(x1),
      pJ: x0 => x0.rasterStartMilliseconds,
      pK: () => globalThis._flutter,
      q: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qB: Function.prototype.call.bind(DataView.prototype.setUint8),
      qC: (string, times) => string.repeat(times),
      qD: x0 => new ResizeObserver(x0),
      qE: x0 => x0.multiline,
      qF: x0 => x0.location,
      qG: (x0,x1) => x0.removeAttribute(x1),
      qH: (x0,x1,x2) => x0.set(x1,x2),
      qI: x0 => x0.name,
      qJ: x0 => x0.imageBitmaps,
      r: (x0,x1) => x0.focus(x1),
      rB: Function.prototype.call.bind(DataView.prototype.setInt8),
      rC: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      rD: (x0,x1) => x0.getPropertyValue(x1),
      rE: (o, p, r) => o.replaceAll(p, () => r),
      rF: x0 => x0.pathname,
      rG: x0 => x0.isConnected,
      rH: x0 => x0.fontFallbackBaseUrl,
      rI: x0 => x0.statusText,
      rJ: x0 => x0.canvasKitMaximumSurfaces,
      s: () => ({}),
      sB: Function.prototype.call.bind(DataView.prototype.getInt8),
      sC: x0 => x0.tabIndex,
      sD: x0 => globalThis.parseFloat(x0),
      sE: x0 => x0.deltaMode,
      sF: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      sG: x0 => x0.click(),
      sH: (handle) => clearInterval(handle),
      sI: x0 => x0.url,
      sJ: x0 => x0.hostElement,
      t: (o, p, v) => o[p] = v,
      tB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      tC: (x0,x1) => x0.contains(x1),
      tD: (x0,x1) => x0.getComputedStyle(x1),
      tE: x0 => x0.deltaY,
      tF: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      tG: (x0,x1) => x0.getElementsByClassName(x1),
      tH: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      tI: x0 => x0.status,
      tJ: x0 => x0.location,
      u: () => [],
      uB: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      uC: x0 => x0.activeElement,
      uD: x0 => x0.documentElement,
      uE: x0 => x0.deltaX,
      uF: o => Object.keys(o),
      uG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      uH: () => Date.now(),
      uI: x0 => x0.getReader(),
      uJ: (x0,x1) => x0.getModifierState(x1),
      v: (a, i) => a.push(i),
      vB: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      vC: x0 => x0.parentNode,
      vD: x0 => x0.computedStyleMap(),
      vE: x0 => x0.wheelDeltaY,
      vF: x0 => x0.state,
      vG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      vH: (x0,x1,x2) => x0.insertBefore(x1,x2),
      vI: x0 => x0.read(),
      vJ: x0 => x0.metaKey,
      w: x0 => new Int8Array(x0),
      wB: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      wC: x0 => x0.tagName,
      wD: (x0,x1) => x0.get(x1),
      wE: x0 => x0.wheelDeltaX,
      wF: x0 => x0.hash,
      wG: (x0,x1) => x0.dispatchEvent(x1),
      wH: x0 => x0.id,
      wI: x0 => x0.value,
      wJ: x0 => x0.altKey,
      x: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      xB: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      xC: x0 => x0.target,
      xD: (o, p) => p in o,
      xE: x0 => x0.key,
      xF: x0 => x0.state,
      xG: (x0,x1) => x0.createEvent(x1),
      xH: x0 => x0.offsetHeight,
      xI: x0 => x0.done,
      xJ: x0 => x0.ctrlKey,
      y: x0 => new Uint8Array(x0),
      yB: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      yC: x0 => x0.clientY,
      yD: (x0,x1) => { x0.textContent = x1 },
      yE: x0 => x0.identifier,
      yF: (x0,x1) => x0.go(x1),
      yG: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      yH: x0 => x0.offsetWidth,
      yI: x0 => x0.cancel(),
      yJ: x0 => x0.isComposing,
      z: x0 => new Uint8ClampedArray(x0),
      zB: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      zC: x0 => x0.clientX,
      zD: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      zE: x0 => x0.touches,
      zF: x0 => x0.parentElement,
      zG: x0 => x0.readText(),
      zH: x0 => x0.stopPropagation(),
      zI: x0 => x0.body,
      zJ: x0 => x0.code,

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
