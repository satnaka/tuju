import React, { useCallback, useRef } from "react";
import {
  DynamicColorIOS,
  NativeModules,
  PlatformColor,
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
  navy: DynamicColorIOS({ light: "#103160", dark: "#E5F3FF" }),
  ink: PlatformColor("labelColor"),
  muted: PlatformColor("secondaryLabelColor"),
  blue: DynamicColorIOS({
    light: "#004B85",
    dark: "#86CFFF",
    highContrastLight: "#003F78",
    highContrastDark: "#B9E6FF",
  }),
  selected: DynamicColorIOS({
    light: "rgba(204, 230, 247, 0.83)",
    dark: "rgba(10, 36, 58, 0.83)",
    highContrastLight: "#C5E5FB",
    highContrastDark: "#112D47",
  }),
  field: PlatformColor("tertiarySystemFillColor"),
  shortcut: PlatformColor("quaternarySystemFillColor"),
  separator: PlatformColor("separatorColor"),
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
        <Text style={s.detail} numberOfLines={2}>
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
              title="Preview R&R stops"
              detail="One Utama concept route · Offline preview"
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
        <Segment.Group background={null} style={s.navGroup}>
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

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: "transparent" },
  scroll: { flex: 1 },
  panel: {
    gap: 8,
    paddingHorizontal: 16,
    paddingTop: 8,
    paddingBottom: 12,
  },
  toggle: {
    padding: 0,
    minHeight: 44,
    height: "auto",
    gap: 6,
    flexDirection: "column",
    borderRadius: 0,
    backgroundColor: "transparent",
  },
  handle: { width: 32, height: 4, borderRadius: 2, backgroundColor: colors.separator },
  heading: {
    fontSize: 23,
    lineHeight: 30,
    letterSpacing: -0.5,
    fontWeight: "600",
    color: colors.navy,
    textAlign: "center",
  },
  search: {
    minHeight: 44,
    height: "auto",
    paddingVertical: 8,
    paddingHorizontal: 14,
    gap: 8,
    justifyContent: "flex-start",
    backgroundColor: colors.field,
    borderWidth: 0,
    borderRadius: 24,
    flexDirection: "row",
    alignItems: "center",
  },
  searchLabel: { color: colors.muted, fontSize: 15, flexShrink: 1 },
  shortcuts: { flexDirection: "row", gap: 8 },
  shortcut: {
    backgroundColor: colors.shortcut,
    flex: 1,
    minWidth: 0,
    minHeight: 44,
    height: "auto",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 5,
    padding: 5,
    borderRadius: 16,
  },
  shortcutLabel: {
    fontSize: 14,
    fontWeight: "600",
    color: colors.ink,
    flexShrink: 1,
  },
  row: {
    minHeight: 44,
    height: "auto",
    paddingHorizontal: 12,
    paddingVertical: 4,
    gap: 12,
    flexDirection: "row",
    justifyContent: "flex-start",
    alignItems: "center",
    borderRadius: 0,
    backgroundColor: "transparent",
  },
  stop: {
    minHeight: 48,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderColor: colors.separator,
  },
  rowText: { flex: 1, gap: 2 },
  rowTitle: { fontSize: 15, fontWeight: "600", color: colors.ink },
  detail: { fontSize: 12, color: colors.muted },
  nav: {
    padding: 4,
    backgroundColor: "transparent",
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
    borderRadius: 100,
    backgroundColor: "transparent",
  },
  selected: { backgroundColor: colors.selected },
  tabLabel: { fontSize: 11, fontWeight: "600", color: colors.ink },
  selectedText: { color: colors.blue },
});
