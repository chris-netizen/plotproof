"use client";

import { useEffect, useRef } from "react";
import "leaflet/dist/leaflet.css";
import type { Plot } from "@/lib/types";

type LeafletMod = typeof import("leaflet");

function colorFor(p: Plot): string {
  if (p.conflict) return "#d92d20";
  if (p.transferred) return "#4f46e5";
  return "#0f7a3d";
}

export default function PlotsMap({
  plots,
  selectedCell,
  checkPoint,
  onSelectPlot,
  onCheckPoint,
}: {
  plots: Plot[];
  selectedCell: string | null;
  checkPoint: { lat: number; lng: number } | null;
  onSelectPlot: (p: Plot) => void;
  onCheckPoint: (lat: number, lng: number) => void;
}) {
  const divRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<import("leaflet").Map | null>(null);
  const LRef = useRef<LeafletMod | null>(null);
  const markerLayer = useRef<import("leaflet").LayerGroup | null>(null);
  const overlayLayer = useRef<import("leaflet").LayerGroup | null>(null);
  const didFit = useRef(false);
  // Keep latest callbacks without re-initialising the map.
  const onCheck = useRef(onCheckPoint);
  const onSelect = useRef(onSelectPlot);
  onCheck.current = onCheckPoint;
  onSelect.current = onSelectPlot;

  // Init once.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const L = (await import("leaflet")).default as unknown as LeafletMod;
      if (cancelled || !divRef.current || mapRef.current) return;
      LRef.current = L;
      const map = L.map(divRef.current, {
        center: [6.4402, 7.4943],
        zoom: 13,
        zoomControl: true,
      });
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors",
        maxZoom: 19,
      }).addTo(map);
      markerLayer.current = L.layerGroup().addTo(map);
      overlayLayer.current = L.layerGroup().addTo(map);
      map.on("click", (e: import("leaflet").LeafletMouseEvent) => {
        onCheck.current(e.latlng.lat, e.latlng.lng);
      });
      mapRef.current = map;
      renderMarkers();
    })();
    return () => {
      cancelled = true;
      mapRef.current?.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Re-render markers when data/selection changes.
  useEffect(() => {
    renderMarkers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [plots, selectedCell, checkPoint]);

  function renderMarkers() {
    const L = LRef.current;
    const map = mapRef.current;
    const layer = markerLayer.current;
    const overlay = overlayLayer.current;
    if (!L || !map || !layer || !overlay) return;
    layer.clearLayers();
    overlay.clearLayers();

    for (const p of plots) {
      const selected = selectedCell === `${p.cellHex}:${p.index}`;
      const m = L.circleMarker([p.lat, p.lng], {
        radius: selected ? 11 : 7,
        color: "#ffffff",
        weight: 2,
        fillColor: colorFor(p),
        fillOpacity: 0.95,
      });
      m.on("click", (e: import("leaflet").LeafletMouseEvent) => {
        L.DomEvent.stop(e);
        onSelect.current(p);
      });
      m.bindTooltip(p.note || p.cell, { direction: "top" });
      m.addTo(layer);
    }

    if (checkPoint) {
      L.circleMarker([checkPoint.lat, checkPoint.lng], {
        radius: 9,
        color: "#ffffff",
        weight: 3,
        fillColor: "#1b73e8",
        fillOpacity: 1,
      }).addTo(overlay);
    }

    // Fit to plots once.
    if (!didFit.current && plots.length > 0) {
      const bounds = L.latLngBounds(plots.map((p) => [p.lat, p.lng]));
      map.fitBounds(bounds.pad(0.35), { maxZoom: 16 });
      didFit.current = true;
    }
  }

  return <div ref={divRef} style={{ height: "100%", width: "100%" }} />;
}
