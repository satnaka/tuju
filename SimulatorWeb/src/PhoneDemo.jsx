import { useEffect, useRef, useState } from "react";
import { liveSessionUrl } from "./liveSession.js";
import "./phone.css";

const routeNames = {
  routes: "LDP",
  "less-toll": "MEX",
  "toll-free": "MRR2",
  "avoid-tolls": "MRR2",
  "stop-added": "LDP",
};
const events = {
  "Traffic lights":
    "8 lights on the concept route. Four are in the first 12 km.",
  "Accident ahead": "The sample traffic report adds 8 minutes to this route.",
  "Road alerts": "The sample traffic report adds 8 minutes to this route.",
  "AES speed camera":
    "Two camera markers on the concept route, at 16 km and 42 km.",
};
const titles = {
  home: "Home, Kuala Lumpur",
  map: "Map, Kuala Lumpur",
  trips: "Your trips",
  profile: "Profile, Guest",
  routes: "Choose your route",
  "less-toll": "Less toll, via MEX",
  "toll-free": "No toll, via MRR2",
  search: "Find your next destination",
  stops: "R&R on your route",
  "stop-detail": "R&R Sungai Buloh",
  "stop-detail-usj": "R&R USJ",
  account: "Welcome back",
};
const describe = (id) => titles[id] ?? id.replaceAll("-", " ");
const asset = (id) => `/native/${id}.webp`;
function bounds([x, y, w, h]) {
  return {
    left: `${(100 * x) / 440}%`,
    top: `${(100 * y) / 956}%`,
    width: `${(100 * w) / 440}%`,
    height: `${(100 * h) / 956}%`,
  };
}
function useCatalog() {
  const [catalog, setCatalog] = useState(null),
    [error, setError] = useState(false),
    [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let mounted = true;
    fetch("/demo/controls.json")
      .then((r) => {
        if (!r.ok) throw Error("Unable to load controls");
        return r.json();
      })
      .then((value) => {
        if (mounted) {
          setCatalog(value);
          setError(false);
        }
      })
      .catch(() => {
        if (mounted) setError(true);
      });
    return () => {
      mounted = false;
    };
  }, [attempt]);
  return { catalog, error, retry: () => setAttempt((v) => v + 1) };
}
function LiveAppLink() {
  return liveSessionUrl ? (
    <a
      className="tuju-live-link"
      href={liveSessionUrl}
      target="_blank"
      rel="noopener noreferrer"
    >
      Open live app
    </a>
  ) : null;
}
function SearchOverlay({
  query,
  setQuery,
  saved,
  savedSearch,
  route,
  stops,
  results,
}) {
  const text = query.trim().toLowerCase();
  const match = savedSearch
    ? saved
    : "one utama".includes(text) ||
      "1 utama".includes(text) ||
      text.includes("utama");
  const rest =
    !savedSearch &&
    text &&
    (text.includes("r&r") || text.includes("stop") || text.includes("sungai"));
  return (
    <>
      <input
        style={bounds([115, 65, 265, 40])}
        className={"tuju-search-input" + (query ? " filled" : "")}
        aria-label="Search places or addresses"
        placeholder="Search places or addresses"
        type="search"
        autoComplete="off"
        enterKeyHint="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.currentTarget.blur();
            if (text.includes("utama")) results();
          }
        }}
      />
      {(query || savedSearch) && (
        <div
          className="tuju-search-results"
          style={bounds([24, 503, 392, 329])}
        >
          <h3>{savedSearch ? "Saved places" : "Search results"}</h3>
          {match && (
            <button className="tuju-search-place" onClick={route}>
              One Utama<small>East Entrance · Petaling Jaya</small>
            </button>
          )}
          {rest && (
            <button className="tuju-search-place" onClick={stops}>
              Preview R&amp;R stops
              <small>One Utama concept route · Offline preview</small>
            </button>
          )}
          {!match && !rest && (
            <p>
              {savedSearch
                ? "Save a destination using its heart button."
                : "Live place search is available in the iPhone app."}
            </p>
          )}
          {!match && !rest && !savedSearch && <LiveAppLink />}
          <button onClick={route}>Explore the One Utama concept route</button>
        </div>
      )}
    </>
  );
}
// The image and touch targets use the same native 440 × 956 pt display coordinates.
export default function PhoneDemo({
  trips = [],
  onCompleteTrip,
  onScreenChange,
}) {
  const { catalog, error, retry } = useCatalog();
  const [stack, setStack] = useState(["home"]);
  const [query, setQuery] = useState(""),
    [savedSearch, setSavedSearch] = useState(false),
    [saved, setSaved] = useState(false);
  const [selected, setSelected] = useState("routes"),
    [simple, setSimple] = useState(false),
    [step, setStep] = useState(0);
  const [dialog, setDialog] = useState(null);
  const touch = useRef(null);
  const screen = stack.at(-1);
  const available = (id) => Boolean(catalog && Object.hasOwn(catalog, id));
  const first = (ids) => ids.find(available);
  const notice = (title, message, button = "OK") =>
    setDialog({ title, message, actions: [[button, "dismiss"]] });
  const liveNotice = (title, message) =>
    setDialog({ title, message, live: true, actions: [["OK", "dismiss"]] });
  const unavailable = () =>
    liveNotice(
      "iPhone app feature",
      "This feature is available in TuJu on iPhone. You can explore the One Utama concept journey in this simulator.",
    );
  function nav(id, replace = false) {
    if (!available(id)) return unavailable();
    setDialog(null);
    setStack((prev) => (replace ? [...prev.slice(0, -1), id] : [...prev, id]));
  }
  function back() {
    if (dialog) {
      setDialog(null);
      return;
    }
    setStack((prev) => (prev.length > 1 ? prev.slice(0, -1) : ["home"]));
  }
  function tab(name) {
    if (name === "profile") {
      nav("profile");
      return;
    }
    const page =
      name === "trips" && trips.length
        ? first(["trips-filled", "trips-recent", "trips"])
        : name;
    setDialog(null);
    setStack([page]);
    setQuery("");
    setSavedSearch(false);
  }
  function search(term = "", savedOnly = false) {
    setQuery(term);
    setSavedSearch(savedOnly);
    if (screen !== "search") nav("search");
  }
  function freshRoute(stops = false) {
    setSelected("routes");
    setSimple(false);
    setStep(0);
    setDialog(null);
    setStack((p) => [...p, "routes", ...(stops ? ["stops"] : [])]);
  }
  function selectRoute(id) {
    setSelected(id);
    nav(id, true);
  }
  function driveFrame(n, alternate) {
    const road = {
      routes: "ldp",
      "less-toll": "mex",
      "toll-free": "mrr2",
      "avoid-tolls": "mrr2",
      "stop-added": "stop",
    }[selected];
    const suffix = alternate ? "-simple" : "";
    return first(
      n === 0
        ? [
            `drive-${road}${suffix}`,
            `driving-${road}${suffix}`,
            alternate ? "driving-simple" : "driving",
          ]
        : [
            `drive-${road}-step-${n}${suffix}`,
            `drive-step-${n}${suffix}`,
            `drive-step-${n}`,
            ...(n === 2 ? ["arrival", "arrival-step", "drive-final"] : []),
          ],
    );
  }
  function offerFeaturedDrive() {
    setDialog({
      title: "Continue the guided drive",
      live: true,
      message:
        "The complete step-by-step preview follows the recommended LDP route to One Utama.",
      actions: [
        ["Open LDP route", "new-route"],
        ["Back", "dismiss"],
      ],
    });
  }
  function act(action) {
    if (action === "back") return back();
    if (action === "dismiss") {
      setDialog(null);
      return;
    }
    if (action.startsWith("tab:")) return tab(action.slice(4));
    if (action === "search:R&R" && available("rest-search"))
      return nav("rest-search");
    if (action === "search" || action.startsWith("search:"))
      return search(action.slice(7));
    if (action === "new-route") return freshRoute();
    if (action === "launch-stops") return freshRoute(true);
    if (action.startsWith("pick:")) return selectRoute(action.slice(5));
    if (action.startsWith("swap:")) return nav(action.slice(5), true);
    if (action === "saved" && screen === "search") return search("", true);
    if (action === "save") {
      setSaved(!saved);
      return;
    }
    if (action === "add-stop" && screen === "stop-detail") {
      setDialog({
        title: "Rest stop preview",
        live: true,
        message:
          "The guided route includes R&R USJ. Compare the quieter stops to add it.",
        actions: [
          ["Compare stops", "stops-compare"],
          ["Back", "dismiss"],
        ],
      });
      return;
    }
    if (["add-stop", "remove-stop"].includes(action)) {
      const next = action === "add-stop" ? "stop-added" : "routes";
      setSelected(next);
      setStack((p) => [
        ...p.slice(
          0,
          Math.max(
            1,
            p.findIndex((k) => k in routeNames),
          ),
        ),
        next,
      ]);
      return;
    }
    if (
      (action === "route-detail" || action === "toggle-mode") &&
      selected !== "routes" &&
      !available(`details-${routeNames[selected]?.toLowerCase()}`)
    )
      return offerFeaturedDrive();
    if (action === "route-detail")
      return nav(
        first([`details-${routeNames[selected]?.toLowerCase()}`, "details"]),
      );
    if (action === "start" && selected === "stop-added")
      return offerFeaturedDrive();
    if (action === "start") {
      setStep(0);
      setSimple(false);
      onCompleteTrip?.({
        place: "One Utama",
        road: routeNames[selected] ?? "LDP",
        distance: {
          routes: 55,
          "stop-added": 58,
          "less-toll": 63,
          "toll-free": 76,
          "avoid-tolls": 76,
        }[selected],
        date: new Date().toISOString(),
      });
      return nav(driveFrame(0, false));
    }
    if (action === "complete") {
      setStack(["home"]);
      setStep(0);
      setSimple(false);
      return;
    }
    if (action === "exit-trip") {
      setStack((p) =>
        p.slice(
          0,
          Math.max(
            1,
            p.findIndex((s) => s.startsWith("driv")),
          ),
        ),
      );
      return;
    }
    if (action === "advance" && selected !== "routes")
      return offerFeaturedDrive();
    if (action === "advance") {
      const next = driveFrame(step + 1, simple);
      if (!next) return act("complete");
      setStep(step + 1);
      setSimple(next.includes("simple"));
      return nav(next, true);
    }
    if (action === "toggle-mode") {
      const next = driveFrame(step, !simple);
      if (next === screen) return unavailable();
      if (next) {
        setSimple(!simple);
        nav(next, true);
      }
      return;
    }
    if (action === "toggle-card")
      return nav(first([screen + "-collapsed", "drive-collapsed"]));
    if (action === "read") {
      const instruction = [
        "Continue straight",
        "Keep left at the exit",
        "Arrive at One Utama",
      ][Math.min(step, 2)];
      if (window.speechSynthesis) {
        window.speechSynthesis.cancel();
        window.speechSynthesis.speak(new SpeechSynthesisUtterance(instruction));
      } else notice("Route instruction", instruction);
      return;
    }
    if (action.startsWith("event:")) {
      const event = action.slice(6);
      return notice(event, events[event], "Back to route");
    }
    if (action === "show-rates")
      return available("stop-rates")
        ? nav("stop-rates")
        : notice("EV charging rates", "10 kWh · RM15.00     20 kWh · RM30.00");
    if (action === "categories") {
      setDialog({
        title: "More categories",
        actions: ["Petrol", "Parking", "EV Charge", "Hotel", "Hospital", "Food"]
          .map((n) => [n, "search:" + n])
          .concat([["Cancel", "dismiss"]]),
      });
      return;
    }
    if (action === "report") {
      setDialog({
        title: "Add a concept road report",
        message: "Reports in this walkthrough are stored on this device.",
        actions: ["Accident", "Traffic", "Road hazard"]
          .map((n) => [n, "report:" + n])
          .concat([["Cancel", "dismiss"]]),
      });
      return;
    }
    if (action.startsWith("report:")) {
      try {
        const prior = JSON.parse(
          sessionStorage.getItem("tuju.reports") || "[]",
        );
        sessionStorage.setItem(
          "tuju.reports",
          JSON.stringify([action.slice(7), ...prior].slice(0, 20)),
        );
      } catch {}
      return notice("Concept report saved", "", "Done");
    }
    if (action === "native:live-drive")
      return liveNotice(
        "Drive with TuJu",
        "Live driving directions use Apple Maps in TuJu on iPhone. To try the guided drive here, choose Explore the One Utama concept route in Search.",
      );
    if (action === "native:sign-in")
      return liveNotice(
        "Sign in to TuJu",
        "Account sign-in is available in the iPhone app. You can explore this simulator as a guest.",
      );
    if (action === "native:location")
      return liveNotice(
        "Kuala Lumpur",
        "This simulator shows TuJu’s Kuala Lumpur preview. Open TuJu on iPhone to use your current location.",
      );
    if (action.startsWith("native:")) return unavailable();
    if (action === "done-road") {
      setStack((p) => p.slice(0, Math.max(1, p.indexOf("road-preview"))));
      return;
    }
    return nav(action);
  }
  useEffect(() => {
    onScreenChange?.(asset(screen));
  }, [screen, onScreenChange]);
  useEffect(() => {
    const neighbors = {
      home: ["search", "map", "trips", "stops"],
      search: ["routes", "stops"],
      routes: ["driving", "less-toll", "toll-free"],
      stops: ["stop-detail", "stops-compare"],
    };
    for (const id of neighbors[screen] ?? [])
      if (catalog?.[id]) {
        const img = new Image();
        img.src = asset(id);
      }
  }, [screen, catalog]);
  const actions = (catalog?.[screen] ?? []).filter(
    ([, action]) =>
      !(
        screen === "search" &&
        (query || savedSearch) &&
        ["launch-stops", "new-route"].includes(action)
      ) && !(screen === "trips-filled" && action === "new-route"),
  );
  return (
    <section
      className="native-demo"
      aria-label={"TuJu app, " + describe(screen)}
      onKeyDown={(e) => {
        if (e.key === "Escape") {
          e.stopPropagation();
          back();
        }
      }}
      onTouchStart={(e) => {
        touch.current = e.touches[0].clientX;
      }}
      onTouchEnd={(e) => {
        if (touch.current === null || !screen.startsWith("welcome-")) return;
        const delta = e.changedTouches[0].clientX - touch.current;
        touch.current = null;
        const n = Number(screen.slice(8));
        if (delta < -45 && n < 4) nav("welcome-" + (n + 1), true);
        if (delta > 45 && n > 1) nav("welcome-" + (n - 1), true);
      }}
    >
      <img
        className="native-frame"
        src={asset(screen)}
        alt={`TuJu on iPhone 18 Pro Max. ${describe(screen)}.`}
        draggable="false"
      />
      <span className="native-screen-name" aria-live="polite">
        {describe(screen)}
      </span>
      <div className="native-touch-layer" inert={dialog ? true : undefined}>
        {actions.map(([label, action, ...rect], i) => (
          <button
            key={screen + i}
            style={bounds(rect)}
            className="native-touch"
            aria-label={label}
            onClick={() => act(action)}
          />
        ))}
        {screen === "trips-filled" && (
          <div className="native-trip-log" style={bounds([0, 164, 440, 682])}>
            <div>
              {trips.map((trip, i) => (
                <button key={i} onClick={() => freshRoute()}>
                  <span aria-hidden="true">🚘</span>
                  <span>
                    <strong>{trip.place}</strong>
                    <small>
                      Concept trip ·{" "}
                      {new Date(trip.date).toLocaleString("en-MY", {
                        day: "numeric",
                        month: "short",
                        year: "numeric",
                        hour: "numeric",
                        minute: "2-digit",
                      })}
                    </small>
                  </span>
                  <span>{trip.distance} km</span>
                </button>
              ))}
            </div>
          </div>
        )}
        {saved && screen in routeNames && (
          <span
            className="native-heart"
            aria-hidden="true"
            style={bounds([385, 89, 34, 33])}
          >
            ♥
          </span>
        )}
        {screen === "search" && (
          <SearchOverlay
            query={query}
            setQuery={(v) => {
              setQuery(v);
              setSavedSearch(false);
            }}
            saved={saved}
            savedSearch={savedSearch}
            results={() => nav("search-results")}
            route={() => freshRoute()}
            stops={() => freshRoute(true)}
          />
        )}
      </div>
      {(dialog || error) && (
        <div className="native-dim">
          <div
            className="native-alert"
            role="alertdialog"
            aria-label={dialog?.title ?? "Screen unavailable"}
          >
            <strong>{dialog?.title ?? "Screen unavailable"}</strong>
            {dialog?.message && <p>{dialog.message}</p>}
            {error ? (
              <button onClick={retry}>Try again</button>
            ) : (
              dialog.actions.map(([label, action], i) => (
                <button
                  autoFocus={i === 0}
                  key={label}
                  onClick={() => {
                    setDialog(null);
                    act(action);
                  }}
                >
                  {label}
                </button>
              ))
            )}
            {(dialog?.live || error) && <LiveAppLink />}
          </div>
        </div>
      )}
    </section>
  );
}
