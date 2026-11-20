import React, { useEffect, useRef } from "react";
import { createRoot } from "react-dom/client";
import { Button } from "@heroui/react/button";
import { ItemCard } from "@heroui-pro/react/item-card";
import { Navbar } from "@heroui-pro/react/navbar";
import home from "../TuJu/Assets.xcassets/HomeHouse.imageset/HomeHouse.svg";
import work from "../TuJu/Assets.xcassets/HomeWork.imageset/HomeWork.svg";
import saved from "../TuJu/Assets.xcassets/HomeSaved.imageset/HomeSaved.svg";
import search from "../TuJu/Assets.xcassets/HomeSearch.imageset/HomeSearch.svg";
import recent from "../TuJu/Assets.xcassets/HomeRecent.imageset/HomeRecent.svg";
import stops from "../TuJu/Assets.xcassets/HomeStop.imageset/HomeStop.svg";
import homeTab from "bootstrap-icons/icons/house-fill.svg";
import mapTab from "bootstrap-icons/icons/map-fill.svg";
import tripsTab from "bootstrap-icons/icons/car-front-fill.svg";
import profileTab from "bootstrap-icons/icons/person-circle.svg";

const send = (message) => window.webkit.messageHandlers.tuju.postMessage(message);

function Shortcut({ title, icon, open, edit }) {
  const timer = useRef();
  const edited = useRef(false);
  const cancel = () => window.clearTimeout(timer.current);
  useEffect(() => cancel, []);

  function openEditor() {
    cancel();
    if (!edited.current) send(edit);
    edited.current = true;
  }

  return (
    <div className="shortcut-wrap"
      onPointerDown={(event) => {
        edited.current = false;
        if (edit && event.pointerType === "touch") timer.current = setTimeout(openEditor, 600);
      }}
      onPointerUp={cancel} onPointerCancel={cancel} onPointerLeave={cancel}
      onContextMenu={(event) => { if (edit) { event.preventDefault(); openEditor(); } }}
      onKeyDown={(event) => {
        if (edit && (event.key === "ContextMenu" || (event.shiftKey && event.key === "F10"))) {
          event.preventDefault();
          edited.current = false;
          openEditor();
        }
      }}>
      <Button className="shortcut" variant="secondary" onPress={() => {
        if (!edited.current) send(open);
        edited.current = false;
      }}>
        <img alt="" src={icon} />{title}
      </Button>
      {edit && <Button className="edit-address" variant="secondary" aria-label={`Change ${title.toLowerCase()} address`} onPress={() => send(edit)}>Change {title.toLowerCase()} address</Button>}
    </div>
  );
}

function PlaceRow({ icon, title, detail, action, highlighted }) {
  return (
    <ItemCard render={(props) => <button {...props} type="button" />} variant={highlighted ? "secondary" : "default"}
      className={highlighted ? "place-row stop-row" : "place-row recent-row"}
      onClick={() => send(action)}>
      <ItemCard.Icon><img src={icon} alt="" /></ItemCard.Icon>
      <ItemCard.Content>
        <ItemCard.Title>{title}</ItemCard.Title>
        <ItemCard.Description>{detail}</ItemCard.Description>
      </ItemCard.Content>
    </ItemCard>
  );
}

function JourneyPanel({ expanded, recentName, recentDetail }) {
  return (
    <section className="journey-panel" aria-label="Journey planner">
      <Button className="panel-toggle" variant="ghost" aria-expanded={expanded} onPress={() => send("toggle")}>
        <span className="handle" aria-hidden="true" />
        Where are we going?
      </Button>
      <Button className="search" variant="secondary" onPress={() => send("search")}>
        <img alt="" src={search} />Search places or addresses
      </Button>
      {expanded && <>
        <div className="shortcuts">
          <Shortcut title="Home" icon={home} open="home" edit="changeHome" />
          <Shortcut title="Work" icon={work} open="work" edit="changeWork" />
          <Shortcut title="Saved" icon={saved} open="saved" />
        </div>
        <PlaceRow icon={recent} title={recentName} detail={recentDetail} action="recent" />
        <PlaceRow icon={stops} title="Plan your next R&R stop" detail="Compare crowd & parking information" action="stops" highlighted />
      </>}
    </section>
  );
}

const tabs = [
  ["Home", homeTab], ["Map", mapTab], ["Trips", tripsTab], ["Profile", profileTab],
];

function Navigation({ selected }) {
  return (
    <Navbar className="tuju-nav" height="auto" position="static" aria-label="Main navigation">
      <Navbar.Content className="nav-items">
        {tabs.map(([title, icon]) => (
          <Navbar.Item key={title}
            className="nav-item" isCurrent={selected === title}
            aria-current={selected === title ? "page" : undefined}
            onClick={() => send("tab" + title)}>
            <span aria-hidden="true" className="tab-icon" style={{ maskImage: `url(${JSON.stringify(icon)})`, WebkitMaskImage: `url(${JSON.stringify(icon)})` }} />
            <Navbar.Label>{title}</Navbar.Label>
          </Navbar.Item>
        ))}
      </Navbar.Content>
    </Navbar>
  );
}

const container = document.getElementById("controls");
const root = createRoot(container);
let lastHeight = 0;
new ResizeObserver(() => {
  const height = Math.ceil(container.getBoundingClientRect().height);
  if (height > 0 && height !== lastHeight) {
    lastHeight = height;
    send({ height });
  }
}).observe(container);

window.renderTuJu = (state) => {
  document.documentElement.style.fontSize = (16 * Math.max(0.8, Number(state.fontScale) || 1)) + "px";
  root.render(state.surface === "tabs" ? <Navigation selected={state.selected} /> : <JourneyPanel {...state} />);
};
send("ready");
