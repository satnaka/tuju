import React, { useCallback, useRef } from "react";
import {
  NativeModules,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import {
  SafeAreaProvider,
  initialWindowMetrics,
} from "react-native-safe-area-context";
import { SvgXml } from "react-native-svg";
import { HeroUINativeProvider } from "heroui-native/provider";
import { Button } from "heroui-native/button";
import { Segment } from "heroui-native-pro/segment";
import icons from "./build/icons";

const colors = {
  navy: "#103160",
  ink: "#0a1c33",
  muted: "#405d7c",
  blue: "#00559e",
  glass: "rgba(240,248,253,.92)",
  edge: "rgba(255,255,255,.94)",
};
const tabs = [
  ["Home", "house-fill"],
  ["Map", "map-fill"],
  ["Trips", "car-front-fill"],
  ["Profile", "person-circle"],
];
const providerConfig = { toast: false, devInfo: { stylingPrinciples: false } };

function Icon({ name, size, color }) {
  return (
    <SvgXml
      xml={icons[name]}
      width={size}
      height={size}
      color={color}
      accessible={false}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    />
  );
}

function Shortcut({ title, icon, open, edit, action }) {
  const didEdit = useRef(false);
  return (
    <Button
      variant="ghost"
      style={s.shortcut}
      accessibilityLabel={title}
      onPressIn={() => {
        didEdit.current = false;
      }}
      onLongPress={
        edit
          ? () => {
              didEdit.current = true;
              action(edit);
            }
          : undefined
      }
      accessibilityHint={
        edit ? "Touch and hold to change this address." : undefined
      }
      accessibilityActions={
        edit
          ? [
              {
                name: "editAddress",
                label: "Change " + title.toLowerCase() + " address",
              },
            ]
          : undefined
      }
      onAccessibilityAction={
        edit
          ? (event) => {
              if (event.nativeEvent.actionName === "editAddress") action(edit);
            }
          : undefined
      }
      onPress={() => {
        if (!didEdit.current) action(open);
      }}
    >
      <Icon name={icon} size={19} />
      <Text style={s.shortcutLabel}>{title}</Text>
    </Button>
  );
}

function PlaceRow({ icon, title, detail, highlighted, onPress }) {
  return (
    <Button
      variant="ghost"
      accessibilityLabel={title + ", " + detail}
      onPress={onPress}
      style={[s.row, highlighted && s.stop]}
    >
      <Icon name={icon} size={22} />
      <View style={s.rowText}>
        <Text style={s.rowTitle} numberOfLines={2}>
          {title}
        </Text>
        <Text style={[s.detail, highlighted && s.stopDetail]} numberOfLines={2}>
          {detail}
        </Text>
      </View>
    </Button>
  );
}

function Journey({ expanded, recentName, recentDetail, action, measure }) {
  return (
    <ScrollView
      bounces={false}
      contentInsetAdjustmentBehavior="never"
      showsVerticalScrollIndicator={false}
      style={s.scroll}
      onContentSizeChange={(_, height) => measure(height)}
    >
      <View style={s.panel}>
        <Button
          variant="ghost"
          accessibilityLabel="Where are we going?"
          accessibilityState={{ expanded }}
          onPress={() => action("toggle")}
          style={s.toggle}
        >
          <View style={s.handle} />
          <Text style={s.heading}>Where are we going?</Text>
        </Button>
        <Button
          variant="ghost"
          accessibilityLabel="Search places or addresses"
          style={s.search}
          onPress={() => action("search")}
        >
          <Icon name="HomeSearch" size={20} />
          <Text style={s.searchLabel}>Search places or addresses</Text>
        </Button>
        {expanded && (
          <>
            <View style={s.shortcuts}>
              <Shortcut
                title="Home"
                icon="HomeHouse"
                open="home"
                edit="changeHome"
                action={action}
              />
              <Shortcut
                title="Work"
                icon="HomeWork"
                open="work"
                edit="changeWork"
                action={action}
              />
              <Shortcut
                title="Saved"
                icon="HomeSaved"
                open="saved"
                action={action}
              />
            </View>
            <PlaceRow
              icon="HomeRecent"
              title={recentName}
              detail={recentDetail}
              onPress={() => action("recent")}
            />
            <PlaceRow
              icon="HomeStop"
              highlighted
              title="Plan your next R&R stop"
              detail="Compare crowd & parking information"
              onPress={() => action("stops")}
            />
          </>
        )}
      </View>
    </ScrollView>
  );
}

function Navigation({ selected, action, measure }) {
  return (
    <View onLayout={(event) => measure(event.nativeEvent.layout.height)}>
      <Segment value={selected} style={s.nav}>
        <Segment.Group style={s.navGroup}>
          {tabs.map(([title, icon]) => {
            const active = selected === title;
            return (
              <Segment.Item
                key={title}
                value={title}
                accessibilityRole="tab"
                accessibilityLabel={title}
                accessibilityState={{ selected: active }}
                style={[s.tab, active && s.selected]}
                onPress={() => action("tab" + title)}
              >
                <Icon
                  name={icon}
                  size={23}
                  color={active ? colors.blue : colors.ink}
                />
                <Text style={[s.tabLabel, active && s.selectedText]}>
                  {title}
                </Text>
              </Segment.Item>
            );
          })}
        </Segment.Group>
      </Segment>
    </View>
  );
}

export default function TuJuControls(props) {
  const { surfaceId, surface } = props;
  const lastHeight = useRef(0);
  const action = useCallback(
    (name) => NativeModules.TuJuControlsBridge.sendAction(surfaceId, name),
    [surfaceId],
  );
  const measure = useCallback(
    (raw) => {
      const height = Math.ceil(raw);
      if (height > 0 && height !== lastHeight.current) {
        lastHeight.current = height;
        NativeModules.TuJuControlsBridge.reportHeight(surfaceId, height);
      }
    },
    [surfaceId],
  );
  return (
    <GestureHandlerRootView style={s.root}>
      <SafeAreaProvider initialMetrics={initialWindowMetrics} style={s.root}>
        <HeroUINativeProvider config={providerConfig}>
          {surface === "tabs" ? (
            <Navigation
              selected={props.selected}
              action={action}
              measure={measure}
            />
          ) : (
            <Journey {...props} action={action} measure={measure} />
          )}
        </HeroUINativeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const capsule = {
  borderWidth: 1,
  borderColor: colors.edge,
  backgroundColor: colors.glass,
};
const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: "transparent" },
  scroll: { flex: 1 },
  panel: {
    gap: 9,
    paddingHorizontal: 17,
    paddingTop: 10,
    paddingBottom: 14,
    borderWidth: 1,
    borderColor: colors.edge,
    borderRadius: 27,
    backgroundColor: "#f5fbfd",
    backgroundImage: "linear-gradient(180deg, #e3f6fa 0%, #fbfeff 100%)",
  },
  toggle: {
    padding: 0,
    minHeight: 0,
    height: "auto",
    gap: 9,
    flexDirection: "column",
    borderRadius: 0,
    backgroundColor: "transparent",
  },
  handle: { width: 34, height: 4, borderRadius: 2, backgroundColor: "#287ed1" },
  heading: {
    fontSize: 23,
    lineHeight: 30,
    fontWeight: "600",
    color: colors.navy,
    textAlign: "center",
  },
  search: {
    minHeight: 44,
    height: "auto",
    paddingVertical: 7,
    paddingHorizontal: 15,
    gap: 10,
    justifyContent: "flex-start",
    backgroundColor: "#f4faff",
    borderColor: "#bee1fc",
    borderWidth: 1,
    borderRadius: 24,
    flexDirection: "row",
    alignItems: "center",
  },
  searchLabel: { color: colors.muted, fontSize: 15, flexShrink: 1 },
  shortcuts: { flexDirection: "row", gap: 8 },
  shortcut: {
    ...capsule,
    flex: 1,
    minWidth: 0,
    minHeight: 44,
    height: "auto",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 5,
    padding: 5,
    borderRadius: 17,
  },
  shortcutLabel: {
    fontSize: 14,
    fontWeight: "600",
    color: colors.ink,
    flexShrink: 1,
  },
  row: {
    minHeight: 40,
    height: "auto",
    padding: 0,
    gap: 12,
    flexDirection: "row",
    justifyContent: "flex-start",
    alignItems: "center",
    borderRadius: 0,
    backgroundColor: "transparent",
  },
  stop: {
    ...capsule,
    minHeight: 54,
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: 17,
  },
  rowText: { flex: 1, gap: 2 },
  rowTitle: { fontSize: 15, fontWeight: "600", color: colors.ink },
  detail: { fontSize: 12, color: colors.ink },
  stopDetail: { fontSize: 11 },
  nav: {
    ...capsule,
    borderRadius: 36,
    padding: 3,
    backgroundColor: "#edf4f5",
    backgroundImage: "linear-gradient(180deg, #e3ebed 0%, #fcfefe 100%)",
  },
  navGroup: {
    flexDirection: "row",
    width: "100%",
    padding: 0,
    gap: 0,
    minHeight: 48,
    height: "auto",
    backgroundColor: "transparent",
    borderWidth: 0,
    boxShadow: [],
  },
  tab: {
    flex: 1,
    flexDirection: "column",
    gap: 2,
    minHeight: 48,
    height: "auto",
    minWidth: 0,
    paddingHorizontal: 0,
    paddingVertical: 3,
    justifyContent: "center",
    alignItems: "center",
    borderRadius: 32,
    backgroundColor: "transparent",
  },
  selected: { backgroundColor: "#c6e8ef" },
  tabLabel: { fontSize: 10, fontWeight: "600", color: colors.ink },
  selectedText: { color: colors.blue },
});
