import {
  lazy,
  Suspense,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from "react";
import { Button } from "@heroui/react/button";
import PhoneDemo from "./PhoneDemo.jsx";
import { liveSessionUrl } from "./liveSession.js";

const DeviceInspector = lazy(() => import("./DeviceInspector.jsx"));

export default function App() {
  const stage = useRef(null);
  const phone = useRef(null);
  const sideButton = useRef(null);
  const dragStart = useRef(null);
  const [inspect, setInspect] = useState(false);
  const [screen, setScreen] = useState("/native/home.webp");
  const [trips, setTrips] = useState([]);

  useLayoutEffect(() => {
    function fitPhone() {
      const width = stage.current.clientWidth;
      const height = stage.current.clientHeight;
      const margin = Math.min(14, width * 0.025, height * 0.015);
      const scale = Math.min(
        (width - 2 * margin) / phone.current.offsetWidth,
        (height - 2 * margin) / phone.current.offsetHeight,
      );
      phone.current.style.setProperty("--scale", scale);
    }
    const observer = new ResizeObserver(fitPhone);
    observer.observe(stage.current);
    observer.observe(phone.current);
    fitPhone();
    return () => observer.disconnect();
  }, []);

  function returnToScreen() {
    setInspect(false);
    requestAnimationFrame(() =>
      sideButton.current?.focus({ preventScroll: true }),
    );
  }

  useEffect(() => {
    if (!inspect) return;
    function handleKey(event) {
      if (event.key === "Escape") returnToScreen();
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [inspect]);

  function beginBezelDrag(event) {
    if (event.target !== event.currentTarget || event.button !== 0) return;
    dragStart.current = event.clientX;
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function dragBezel(event) {
    if (
      dragStart.current !== null &&
      Math.abs(event.clientX - dragStart.current) > 12
    ) {
      dragStart.current = null;
      setInspect(true);
    }
  }

  return (
    <main
      className="device-stage"
      ref={stage}
      aria-label="TuJu simulator on iPhone 18 Pro Max"
    >
      <div
        className={"handset" + (inspect ? " handset-hidden" : "")}
        ref={phone}
        inert={inspect}
        aria-hidden={inspect || undefined}
        onPointerDown={beginBezelDrag}
        onPointerMove={dragBezel}
        onLostPointerCapture={() => {
          dragStart.current = null;
        }}
      >
        <span className="metal-key silent-key" aria-hidden="true" />
        <span className="metal-key volume-up" aria-hidden="true" />
        <span className="metal-key volume-down" aria-hidden="true" />
        <Button
          isIconOnly
          variant="ghost"
          ref={sideButton}
          className="power-key"
          aria-label="Inspect iPhone in 3D"
          title="Inspect iPhone in 3D"
          onPress={() => setInspect(true)}
        >
          <span className="side-metal" aria-hidden="true" />
        </Button>
        <div className="screen-glass">
          <PhoneDemo
            trips={trips}
            onCompleteTrip={(trip) => setTrips((current) => [trip, ...current])}
            onScreenChange={setScreen}
          />
          <a
            className="live-island"
            href={liveSessionUrl}
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Open live TuJu on Appetize in a new tab"
            title="Open the live iOS app on Appetize"
          >
            <span aria-hidden="true" className="live-play" />
            Live app
          </a>
        </div>
      </div>
      {inspect && (
        <Suspense fallback={null}>
          <DeviceInspector screenSrc={screen} onReturn={returnToScreen} />
        </Suspense>
      )}
    </main>
  );
}
