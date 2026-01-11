import { ImageResponse } from "next/og";
import type { CSSProperties } from "react";
import styleJson from "./style.json";

export const runtime = "edge";

type StyleConfig = {
  bg?: string;
  label?: string;
  subtle?: string;
  accent?: string;
  pastDay?: string;
  futureDay?: string;
  futureSaturday?: string;
  sundayRed?: string;
  sundayRedInnerWhenBirthday?: string;
  birthdayRing?: string;
  todayHalo?: string;
  sundayRingColor?: string;
  barTrack?: string;

  topMarginPct?: number;
  bottomMarginPct?: number;
  contentWidthPct?: number;
  colGapPct?: number;
  rowGapPct?: number;

  showSundayRing?: boolean;
  birthdays?: string[];
};

const DEFAULT_STYLE: Required<StyleConfig> = {
  bg: "#0f0f10",
  label: "#a9a9aa",
  subtle: "#7c7c7d",
  accent: "#ff7a00",
  pastDay: "#e9e9ea",
  futureDay: "#2f2f31",
  futureSaturday: "#6b6b70",
  sundayRed: "#ff3b30",
  sundayRedInnerWhenBirthday: "#b3261e",
  birthdayRing: "#ff3b30",
  todayHalo: "#f2f2f2",
  sundayRingColor: "#f2f2f2",
  barTrack: "#1b1b1d",

  topMarginPct: 0.3,
  bottomMarginPct: 0.22,
  contentWidthPct: 0.72,
  colGapPct: 0.06,
  rowGapPct: 0.055,

  showSundayRing: true,
  birthdays: ["05-01", "03-28", "10-08", "11-08", "11-24"],
};

const STYLE: Required<StyleConfig> = {
  ...DEFAULT_STYLE,
  ...(styleJson as StyleConfig),
};

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function monFirstIndex(utcDay: number) {
  return (utcDay + 6) % 7;
}

function pad2(n: number) {
  return String(n).padStart(2, "0");
}

function daysInMonthUTC(year: number, month0: number) {
  return new Date(Date.UTC(year, month0 + 1, 0)).getUTCDate();
}

function isLeapYear(y: number) {
  return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
}

function dayOfYearUTC(d: Date) {
  const start = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const diff = d.getTime() - start.getTime();
  return Math.floor(diff / 86400000) + 1;
}

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);

  const width = parseInt(searchParams.get("width") ?? "1179", 10);
  const height = parseInt(searchParams.get("height") ?? "2556", 10);

  const dateParam = searchParams.get("date");
  const today = dateParam ? new Date(`${dateParam}T00:00:00Z`) : new Date();

  const year = today.getUTCFullYear();
  const todayMidnight = new Date(Date.UTC(year, today.getUTCMonth(), today.getUTCDate()));

  const totalDays = isLeapYear(year) ? 366 : 365;
  const doy = dayOfYearUTC(today);
  const daysLeft = totalDays - doy;
  const progress = Math.min(1, Math.max(0, doy / totalDays));
  const pct = Math.round(progress * 100);

  const BIRTHDAYS = new Set<string>((STYLE.birthdays ?? []).map((s) => String(s).trim()).filter(Boolean));

  const topMargin = Math.round(height * (STYLE.topMarginPct ?? 0.3));
  const bottomMargin = Math.round(height * (STYLE.bottomMarginPct ?? 0.22));

  const contentW = Math.round(width * (STYLE.contentWidthPct ?? 0.72));
  const leftRight = Math.round((width - contentW) / 2);

  const colGap = Math.round(width * (STYLE.colGapPct ?? 0.06));
  const rowGap = Math.round(width * (STYLE.rowGapPct ?? 0.055));

  const cols = 3;
  const monthW = Math.floor((contentW - colGap * (cols - 1)) / cols);

  const dotGap = Math.max(10, Math.round(monthW * 0.06));
  const dot = Math.max(10, Math.floor((monthW - dotGap * 6) / 7));

  const ringBirthday = Math.max(3, Math.round(dot * 0.22));
  const todayPad = Math.max(2, Math.round(dot * 0.16));
  const ringSunday = Math.max(2, Math.round(dot * 0.14));

  const labelFont = Math.max(18, Math.round(dot * 1.25));
  const labelH = Math.round(dot * 2.0);

  const dotsH = 6 * dot + 5 * dotGap;
  const monthH = labelH + dotsH;

  const footerGap = Math.max(6, Math.round(dot * 0.45));
  const footerFont = Math.max(22, Math.round(width * 0.04));

  const barH = Math.max(6, Math.round(width * 0.008));
  const barGap = Math.max(8, Math.round(barH * 1.2));

  const bg = STYLE.bg;
  const label = STYLE.label;
  const subtle = STYLE.subtle;
  const accent = STYLE.accent;

  const pastDay = STYLE.pastDay;
  const futureDay = STYLE.futureDay;

  const futureSaturday = STYLE.futureSaturday;
  const sundayRed = STYLE.sundayRed;
  const sundayRedInnerWhenBirthday = STYLE.sundayRedInnerWhenBirthday;

  const birthdayRing = STYLE.birthdayRing;
  const todayHalo = STYLE.todayHalo;
  const sundayRingColor = STYLE.sundayRingColor;

  const barTrack = STYLE.barTrack;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          background: bg,
          display: "flex",
          flexDirection: "column",
          boxSizing: "border-box",
        }}
      >
        <div style={{ display: "flex", height: topMargin }} />

        <div
          style={{
            display: "flex",
            flexDirection: "column",
            width: contentW,
            marginLeft: leftRight,
            marginRight: leftRight,
            boxSizing: "border-box",
          }}
        >
          <div
            style={
              {
                display: "flex",
                flexDirection: "row",
                flexWrap: "wrap",
                gap: colGap,
                rowGap,
                width: contentW,
                boxSizing: "border-box",
              } as CSSProperties
            }
          >
            {MONTHS.map((mName, month0) => {
              const first = new Date(Date.UTC(year, month0, 1));
              const startOffset = monFirstIndex(first.getUTCDay());
              const dim = daysInMonthUTC(year, month0);

              const total = startOffset + dim;
              const paddedTotal = Math.ceil(total / 7) * 7;

              return (
                <div
                  key={mName}
                  style={{
                    width: monthW,
                    height: monthH,
                    display: "flex",
                    flexDirection: "column",
                    boxSizing: "border-box",
                  }}
                >
                  <div
                    style={{
                      height: labelH,
                      display: "flex",
                      flexDirection: "row",
                      alignItems: "flex-end",
                      justifyContent: "flex-start",
                      fontSize: labelFont,
                      fontWeight: 600,
                      color: label,
                      letterSpacing: 0.2,
                    }}
                  >
                    {mName}
                  </div>

                  <div
                    style={{
                      display: "flex",
                      flexDirection: "row",
                      flexWrap: "wrap",
                      gap: dotGap,
                      alignContent: "flex-start",
                      width: monthW,
                      boxSizing: "border-box",
                    }}
                  >
                    {Array.from({ length: paddedTotal }).map((_, idx) => {
                      const dayNum = idx - startOffset + 1;
                      const inMonth = dayNum >= 1 && dayNum <= dim;

                      if (!inMonth) {
                        return (
                          <div
                            key={idx}
                            style={{
                              width: dot,
                              height: dot,
                              display: "flex",
                              opacity: 0,
                            }}
                          />
                        );
                      }

                      const weekdayIndex = (startOffset + (dayNum - 1)) % 7; // 0=Lun..6=Dom
                      const isSaturday = weekdayIndex === 5;
                      const isSunday = weekdayIndex === 6;

                      const dayDate = new Date(Date.UTC(year, month0, dayNum));
                      const isToday = dayDate.getTime() === todayMidnight.getTime();
                      const isPast = dayDate.getTime() < todayMidnight.getTime();

                      const mmdd = `${pad2(month0 + 1)}-${pad2(dayNum)}`;
                      const isBirthday = BIRTHDAYS.has(mmdd);

                      let fillBase: string;
                      if (isPast) {
                        fillBase = pastDay;
                      } else if (isSunday) {
                        fillBase = isBirthday ? sundayRedInnerWhenBirthday : sundayRed;
                      } else if (isSaturday) {
                        fillBase = futureSaturday;
                      } else {
                        fillBase = futureDay;
                      }

                      if (isToday) {
                        const outerStyle: CSSProperties = {
                          display: "flex",
                          width: dot,
                          height: dot,
                          borderRadius: 999,
                          boxSizing: "border-box",
                          background: todayHalo,
                          padding: todayPad,
                          alignItems: "center",
                          justifyContent: "center",
                        };

                        if (isBirthday) {
                          outerStyle.border = `${ringBirthday}px solid ${birthdayRing}`;
                        } else if (STYLE.showSundayRing && isSunday) {
                          outerStyle.border = `${ringSunday}px solid ${sundayRingColor}`;
                        }

                        const innerStyle: CSSProperties = {
                          display: "flex",
                          width: "100%",
                          height: "100%",
                          borderRadius: 999,
                          background: accent,
                        };

                        return (
                          <div key={idx} style={outerStyle}>
                            <div style={innerStyle} />
                          </div>
                        );
                      }

                      let dotStyle: CSSProperties = {
                        display: "flex",
                        width: dot,
                        height: dot,
                        borderRadius: 999,
                        background: fillBase,
                        boxSizing: "border-box",
                      };

                      if (isBirthday) {
                        dotStyle = { ...dotStyle, border: `${ringBirthday}px solid ${birthdayRing}` };
                      } else if (STYLE.showSundayRing && !isPast && isSunday) {
                        dotStyle = { ...dotStyle, border: `${ringSunday}px solid ${sundayRingColor}` };
                      }

                      return <div key={idx} style={dotStyle} />;
                    })}
                  </div>
                </div>
              );
            })}
          </div>

          <div style={{ display: "flex", height: footerGap }} />

          <div
            style={{
              display: "flex",
              flexDirection: "row",
              justifyContent: "space-between",
              alignItems: "center",
              width: contentW,
              fontSize: footerFont,
              fontWeight: 700,
              letterSpacing: 0.2,
            }}
          >
            <div style={{ display: "flex", color: accent }}>{daysLeft}d left</div>
            <div style={{ display: "flex", color: subtle }}>{pct}%</div>
          </div>

          <div style={{ display: "flex", height: barGap }} />

          <div
            style={{
              display: "flex",
              flexDirection: "row",
              width: contentW,
              height: barH,
              background: barTrack,
              borderRadius: 999,
              boxSizing: "border-box",
              overflow: "hidden",
            }}
          >
            <div
              style={{
                display: "flex",
                width: `${Math.round(progress * 1000) / 10}%`,
                height: "100%",
                background: accent,
              }}
            />
          </div>
        </div>

        <div style={{ display: "flex", height: bottomMargin }} />
      </div>
    ),
    {
      width,
      height,
      headers: { "Cache-Control": "no-store" },
    }
  );
}
