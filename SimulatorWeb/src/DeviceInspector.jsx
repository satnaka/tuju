import { useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import "./inspector.css";

const device = {
  name: "iPhone 18 Pro Max",
  color: "#a8bed3",
  width: 2.46,
  height: 5.06,
  corner: 0.36,
};

const initialPose = { yaw: -0.56, pitch: -0.075 };
const clamp = THREE.MathUtils.clamp;

function roundedOutline(width, height, radius) {
  const x = width / 2,
    y = height / 2,
    r = Math.min(radius, x, y);
  const shape = new THREE.Shape();
  shape.moveTo(-x + r, -y);
  shape.lineTo(x - r, -y);
  shape.absarc(x - r, -y + r, r, -Math.PI / 2, 0);
  shape.lineTo(x, y - r);
  shape.absarc(x - r, y - r, r, 0, Math.PI / 2);
  shape.lineTo(-x + r, y);
  shape.absarc(-x + r, y - r, r, Math.PI / 2, Math.PI);
  shape.lineTo(-x, -y + r);
  shape.absarc(-x + r, -y + r, r, Math.PI, 1.5 * Math.PI);
  return shape;
}

function roundedPart(
  parent,
  material,
  width,
  height,
  thickness,
  corner,
  bevel,
  x,
  y,
  z,
) {
  const geo = new THREE.ExtrudeGeometry(
    roundedOutline(width - 2 * bevel, height - 2 * bevel, corner - bevel),
    {
      depth: thickness - 2 * bevel,
      bevelEnabled: bevel > 0,
      bevelSize: bevel,
      bevelThickness: bevel,
      bevelSegments: 3,
      curveSegments: 8,
    },
  );
  geo.translate(0, 0, -thickness / 2 + bevel);
  const part = new THREE.Mesh(geo, material);
  part.position.set(x, y, z);
  parent.add(part);
  return part;
}

function cylinder(parent, material, radius, thickness, x, y, z) {
  const geo = new THREE.CylinderGeometry(radius, radius, thickness, 48);
  geo.rotateX(Math.PI / 2);
  const part = new THREE.Mesh(geo, material);
  part.position.set(x, y, z);
  parent.add(part);
}

function canvasTexture(width, height, draw) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  draw(canvas.getContext("2d"));
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

// Apple symbol outline from Simple Icons (CC0).
const appleMark =
  "M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701";

function addBackMark(phone) {
  const map = canvasTexture(192, 192, (ctx) => {
    ctx.scale(8, 8);
    const finish = ctx.createLinearGradient(4, 1, 22, 23);
    finish.addColorStop(0, "#75889b");
    finish.addColorStop(0.68, "#4f677f");
    finish.addColorStop(1, "#819bae");
    ctx.fillStyle = finish;
    ctx.fill(new Path2D(appleMark));
  });
  const material = new THREE.MeshBasicMaterial({
    map,
    transparent: true,
    opacity: 0.77,
    depthWrite: false,
    toneMapped: false,
  });
  const mark = new THREE.Mesh(new THREE.PlaneGeometry(0.51, 0.51), material);
  mark.position.set(0, -0.1, 0.147);
  phone.add(mark);
}

function lensSurface() {
  const map = canvasTexture(192, 192, (ctx) => {
    const glass = ctx.createRadialGradient(90, 100, 4, 96, 96, 96);
    for (const [offset, color] of [
      [0, "#090e18"],
      [0.23, "#121824"],
      [0.3, "#202735"],
      [0.33, "#151c2b"],
      [0.46, "#171d25"],
      [0.48, "#323841"],
      [0.51, "#151920"],
      [0.76, "#0e141c"],
      [0.93, "#1a232d"],
      [1, "#090b0e"],
    ]) {
      glass.addColorStop(offset, color);
    }
    ctx.fillStyle = glass;
    ctx.fillRect(0, 0, 192, 192);
    const glow = (x, y, radius, inner, outer) => {
      const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
      gradient.addColorStop(0, inner);
      gradient.addColorStop(1, outer);
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, 192, 192);
    };
    glow(76, 56, 35, "#5792cb96", "#486c9e00");
    glow(107, 116, 19, "#a568ca6c", "#a568ca00");
    glow(52, 79, 6, "#c9d8e77f", "#c9d8e700");
  });
  return new THREE.MeshBasicMaterial({ map, toneMapped: false });
}

function makeScreen(width, height, corner) {
  const map = canvasTexture(512, 1024, (ctx) => {
    const bg = ctx.createLinearGradient(80, 0, 430, 1000);
    bg.addColorStop(0, "#075790");
    bg.addColorStop(0.55, "#154590");
    bg.addColorStop(1, "#0b234c");
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, 512, 1024);
    for (let i = -20; i < 28; i++) {
      ctx.beginPath();
      ctx.moveTo(-50, 320 + i * 16);
      ctx.bezierCurveTo(
        120,
        270 + i * 12,
        180,
        760 + i * 17,
        575,
        605 + i * 23,
      );
      ctx.strokeStyle = i % 5 === 0 ? "#7ed4ff50" : "#b2e3ff25";
      ctx.lineWidth = i % 5 === 0 ? 1.7 : 1;
      ctx.stroke();
    }
    ctx.fillStyle = "#eef9ff";
    ctx.font = "600 20px system-ui, sans-serif";
    ctx.fillText("9:41", 36, 52);
    ctx.fillStyle = "#0a1320";

    ctx.fillStyle = "#f3faff";
    ctx.textAlign = "center";
    ctx.font = "650 102px system-ui, sans-serif";
    ctx.fillText("TuJu", 256, 510);
    ctx.font = "400 21px system-ui, sans-serif";
    ctx.fillText("Navigation simulator", 256, 553);
    ctx.beginPath();
    ctx.roundRect(184, 993, 144, 7, 4);
    ctx.fill();
  });
  const geo = new THREE.ShapeGeometry(
    roundedOutline(width, height, corner),
    12,
  );
  const pos = geo.attributes.position,
    uv = geo.attributes.uv;
  for (let i = 0; i < pos.count; i++)
    uv.setXY(i, pos.getX(i) / width + 0.5, pos.getY(i) / height + 0.5);
  const screen = new THREE.Mesh(
    geo,
    new THREE.MeshBasicMaterial({ map, toneMapped: false }),
  );
  screen.rotation.y = Math.PI;
  screen.position.z = -0.15;
  return screen;
}

function createPhone() {
  const { width, height, corner, color } = device;
  const phone = new THREE.Group();
  const matte = (color, roughness = 0.4, metalness = 0.18) =>
    new THREE.MeshStandardMaterial({ color, roughness, metalness });
  const back = matte(color, 0.44, 0.32);
  const rail = matte(
    new THREE.Color(color).lerp(new THREE.Color("#60707e"), 0.47),
    0.22,
    0.88,
  );
  const chrome = matte("#a2aeb6", 0.19, 0.93);
  const band = matte("#535e66", 0.62, 0.22);
  const black = matte("#10161c", 0.3, 0.32);
  const glass = lensSurface();
  const flash = matte("#f8edc5", 0.26, 0.12);
  roundedPart(phone, rail, width, height, 0.27, corner, 0.038, 0, 0, 0);
  roundedPart(
    phone,
    back,
    width - 0.065,
    height - 0.065,
    0.038,
    corner - 0.035,
    0.012,
    0,
    0,
    0.125,
  );
  roundedPart(
    phone,
    black,
    width - 0.045,
    height - 0.045,
    0.04,
    corner - 0.026,
    0.012,
    0,
    0,
    -0.126,
  );
  const screen = makeScreen(width - 0.125, height - 0.125, corner - 0.074);
  phone.add(screen);
  roundedPart(
    phone,
    new THREE.MeshBasicMaterial({ color: "#07090d", toneMapped: false }),
    0.72,
    0.151,
    0.012,
    0.073,
    0.003,
    0,
    height / 2 - 0.211,
    -0.157,
  );
  const key = (x, y, length) =>
    roundedPart(phone, rail, 0.053, length, 0.095, 0.025, 0.008, x, y, 0);
  key(width / 2, 0.65, 0.53);
  key(-width / 2, 0.79, 0.4);
  key(-width / 2, 0.29, 0.4);
  for (const x of [-width / 2, width / 2]) {
    for (const y of [-height * 0.35, height * 0.35]) {
      roundedPart(phone, band, 0.025, 0.037, 0.195, 0.004, 0.002, x, y, 0);
    }
  }

  const lens = (x, y, z, r) => {
    cylinder(phone, chrome, r, 0.074, x, y, z + 0.034);
    cylinder(phone, black, r * 0.94, 0.04, x, y, z + 0.073);
    const face = new THREE.Mesh(new THREE.CircleGeometry(r * 0.85, 64), glass);
    face.position.set(x, y, z + 0.095);
    phone.add(face);
  };
  roundedPart(
    phone,
    back,
    width - 0.18,
    1.3,
    0.104,
    0.28,
    0.033,
    0,
    1.77,
    0.185,
  );
  lens(-0.78, 2.04, 0.237, 0.272);
  lens(-0.78, 1.48, 0.237, 0.272);
  lens(-0.265, 1.76, 0.237, 0.272);
  cylinder(phone, flash, 0.087, 0.012, 0.85, 2.12, 0.244);
  cylinder(phone, black, 0.073, 0.014, 0.84, 1.43, 0.245);
  cylinder(phone, band, 0.023, 0.012, 0.84, 1.79, 0.243);
  addBackMark(phone);
  return { phone, screen };
}

function disposePhone(phone) {
  const geometries = new Set(),
    materials = new Set();
  phone.traverse((part) => {
    if (part.geometry) geometries.add(part.geometry);
    if (part.material) materials.add(part.material);
  });
  geometries.forEach((geometry) => geometry.dispose());
  materials.forEach((material) => {
    material.map?.dispose();
    material.dispose();
  });
}

function FallbackModel({ pose, screenSrc }) {
  return (
    <div className="hardware-fallback" aria-hidden="true">
      <div
        className="hardware-fallback-body"
        style={{
          "--hardware-color": device.color,
          transform: `rotateX(${pose.pitch}rad) rotateY(${pose.yaw}rad) rotateZ(-4deg)`,
        }}
      >
        <div className="hardware-fallback-back">
          <div className="hardware-fallback-cameras">
            <i />
            <i />
            <i />
          </div>
          <svg
            viewBox="0 0 24 24"
            width="19%"
            fill="currentColor"
            aria-hidden="true"
          >
            <path d={appleMark} />
          </svg>
        </div>
        <div className="hardware-fallback-front">
          <b>TuJu</b>
          <span>Navigation simulator</span>
          {screenSrc && (
            <img
              src={screenSrc}
              alt=""
              onError={(event) => {
                event.currentTarget.hidden = true;
              }}
            />
          )}
        </div>
      </div>
    </div>
  );
}

export default function DeviceInspector({
  screenSrc = "/native/home.webp",
  onReturn,
}) {
  const surface = useRef(null);
  const rotation = useRef(initialPose);
  const renderFrame = useRef(null);
  const drag = useRef(null);
  const lastTouch = useRef(null);
  const returning = useRef(false);
  const [fallback, setFallback] = useState(false);
  const [fallbackPose, setFallbackPose] = useState(initialPose);

  useEffect(() => {
    const host = surface.current;
    host.focus({ preventScroll: true });
    rotation.current = { ...initialPose };
    setFallbackPose(initialPose);
    drag.current = null;
    const canvas = document.createElement("canvas");
    canvas.setAttribute("aria-hidden", "true");
    let renderer;
    try {
      renderer = new THREE.WebGLRenderer({
        canvas,
        antialias: true,
        alpha: true,
        powerPreference: "low-power",
      });
    } catch {
      setFallback(true);
      return;
    }
    setFallback(false);
    host.append(canvas);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setClearColor(0, 0);
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.06;
    const scene = new THREE.Scene();
    const environment = new RoomEnvironment();
    const pmrem = new THREE.PMREMGenerator(renderer);
    const lighting = pmrem.fromScene(environment, 0.045);
    scene.environment = lighting.texture;
    environment.dispose();
    pmrem.dispose();
    const key = new THREE.DirectionalLight("#fff9ed", 1.85);
    key.position.set(-4, 7, 6);
    const rim = new THREE.DirectionalLight("#c2e6ff", 2);
    rim.position.set(4, 2, -4);
    scene.add(key, rim);
    const { phone, screen } = createPhone();
    scene.add(phone);
    const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 60);
    let active = true,
      frame = null;
    const render = () => {
      frame = null;
      if (!active) return;
      phone.rotation.set(
        rotation.current.pitch,
        rotation.current.yaw,
        -0.055,
        "YXZ",
      );
      renderer.render(scene, camera);
    };
    renderFrame.current = () => {
      if (frame === null) frame = requestAnimationFrame(render);
    };
    const nativeScreen = new Image();
    nativeScreen.onload = () => {
      if (!active) return;
      const texture = new THREE.Texture(nativeScreen);
      texture.colorSpace = THREE.SRGBColorSpace;
      texture.anisotropy = Math.min(
        8,
        renderer.capabilities.getMaxAnisotropy(),
      );
      texture.needsUpdate = true;
      screen.material.map.dispose();
      screen.material.map = texture;
      renderFrame.current?.();
    };
    if (screenSrc) nativeScreen.src = screenSrc;
    const resize = () => {
      const { clientWidth: w, clientHeight: h } = host;
      if (!w || !h) return;
      camera.aspect = w / h;
      const viewHeight = Math.max(5.72, 3.34 / camera.aspect);
      camera.position.z =
        viewHeight / (2 * Math.tan(THREE.MathUtils.degToRad(17.5)));
      host.parentElement.style.setProperty(
        "--foot-offset",
        `${(2.57 * h) / viewHeight}px`,
      );
      camera.updateProjectionMatrix();
      renderer.setSize(w, h, false);
      renderFrame.current?.();
    };
    const lostContext = (event) => {
      event.preventDefault();
      active = false;
      canvas.hidden = true;
      setFallbackPose({ ...rotation.current });
      setFallback(true);
    };
    canvas.addEventListener("webglcontextlost", lostContext);
    const observer = new ResizeObserver(resize);
    observer.observe(host);
    resize();
    return () => {
      active = false;
      nativeScreen.onload = null;
      renderFrame.current = null;
      if (frame !== null) cancelAnimationFrame(frame);
      observer.disconnect();
      canvas.removeEventListener("webglcontextlost", lostContext);
      disposePhone(phone);
      lighting.dispose();
      renderer.dispose();
      renderer.forceContextLoss();
      canvas.remove();
    };
  }, [screenSrc]);

  function returnToScreen() {
    if (!onReturn || returning.current) return;
    returning.current = true;
    onReturn();
  }

  function rotate(yaw, pitch = 0) {
    rotation.current = {
      yaw: rotation.current.yaw + yaw,
      pitch: clamp(rotation.current.pitch + pitch, -1.18, 1.18),
    };
    if (fallback) setFallbackPose(rotation.current);
    else renderFrame.current?.();
  }
  function onPointerDown(event) {
    if (!event.isPrimary || event.button !== 0) return;
    event.currentTarget.focus({ preventScroll: true });
    event.currentTarget.setPointerCapture(event.pointerId);
    drag.current = {
      x: event.clientX,
      y: event.clientY,
      pointer: event.pointerId,
      moved: false,
    };
  }
  function onPointerMove(event) {
    if (!drag.current || event.pointerId !== drag.current.pointer) return;
    const dx = event.clientX - drag.current.x,
      dy = event.clientY - drag.current.y;
    if (Math.abs(dx) + Math.abs(dy) > 2) drag.current.moved = true;
    rotate(dx * 0.012, dy * 0.008);
    drag.current.x = event.clientX;
    drag.current.y = event.clientY;
  }
  function onPointerUp(event) {
    if (event.pointerType !== "touch" || !drag.current || drag.current.moved)
      return;
    const tap = { t: performance.now(), x: event.clientX, y: event.clientY };
    const previous = lastTouch.current;
    if (
      previous &&
      tap.t - previous.t < 350 &&
      Math.hypot(tap.x - previous.x, tap.y - previous.y) < 24
    ) {
      lastTouch.current = null;
      returnToScreen();
    } else {
      lastTouch.current = tap;
    }
  }
  function onKeyDown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      returnToScreen();
      return;
    }
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      rotate(Math.PI);
      return;
    }
    const movement = {
      ArrowLeft: [-0.22, 0],
      ArrowRight: [0.22, 0],
      ArrowUp: [0, -0.17],
      ArrowDown: [0, 0.17],
    }[event.key];
    if (!movement) return;
    event.preventDefault();
    rotate(...movement);
  }

  return (
    <div className="hardware-inspector">
      <div className="hardware-shadow" aria-hidden="true" />
      <div
        ref={surface}
        className="hardware-inspector-surface"
        tabIndex={0}
        role="group"
        aria-label={`${device.name} model. Drag or use the arrow keys to rotate. Enter flips the phone. Double-click or press Escape to use the screen.`}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onDoubleClick={returnToScreen}
        onLostPointerCapture={() => {
          drag.current = null;
        }}
        onKeyDown={onKeyDown}
      >
        {fallback && (
          <FallbackModel screenSrc={screenSrc} pose={fallbackPose} />
        )}
      </div>
    </div>
  );
}
