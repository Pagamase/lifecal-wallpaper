import { ImageResponse } from "next/og";
import type { CSSProperties } from "react";

export const runtime = "edge";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Semana Lunes->Domingo
function monFirstIndex(utcDay: number) {
  // JS: getUTCDay(): 0=Dom ... 6=Sáb  -> queremos 0=Lun ... 6=Dom
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

  // Defaults: tu tamaño (vertical)
  const width = parseInt(searchParams.get("width") ?? "1179", 10);
  const height = parseInt(searchParams.get("height") ?? "2556", 10);

  // Fecha desde Atajos (YYYY-MM-DD)
  const dateParam = searchParams.get("date");
  const today = dateParam ? new Date(`${dateParam}T00:00:00Z`) : new Date();

  const year = today.getUTCFullYear();
  const todayMidnight = new Date(Date.UTC(year, today.getUTCMonth(), today.getUTCDate()));

  // Progreso anual
  const totalDays = isLeapYear(year) ? 366 : 365;
  const doy = dayOfYearUTC(today);
  const daysLeft = totalDays - doy;
  const progress = Math.min(1, Math.max(0, doy / totalDays));
  const pct = Math.round(progress * 100);

  // =========================
  // Cumples (MM-DD) -> anillo rojo
  // =========================
  const BIRTHDAYS = new Set<string>([
    "05-01",
    "03-28",
    "10-08",
    "11-08",
    "11-24",
  ]);

  // =========================
  // LAYOUT (márgenes grandes)
  // =========================
  const topMargin = Math.round(height * 0.30);
  const bottomMargin = Math.round(height * 0.22);

  const contentW = Math.round(width * 0.72);
  const leftRight = Math.round((width - contentW) / 2);

  const colGap = Math.round(width * 0.06);
  const rowGap = Math.round(width * 0.055);

  const cols = 3;
  const monthW = Math.floor((contentW - colGap * (cols - 1)) / cols);

  const dotGap = Math.max(10, Math.round(monthW * 0.06));
  const dot = Math.max(10, Math.floor((monthW - dotGap * 6) / 7));
  const ring = Math.max(3, Math.round(dot * 0.22)); // grosor anillo cumple
  const todayPad = Math.max(2, Math.round(dot * 0.16)); // grosor del anillo claro de HOY

  const labelFont = Math.max(18, Math.round(dot * 1.25));
  const labelH = Math.round(dot * 2.0);

  const dotsH = 6 * dot + 5 * dotGap;
  const monthH = labelH + dotsH;

  const footerGap = Math.max(6, Math.round(dot * 0.45));
  const footerFont = Math.max(22, Math.round(width * 0.04));

  const barH = Math.max(6, Math.round(width * 0.008));
  const barGap = Math.max(8, Math.round(barH * 1.2));

  // =========================
  // COLORES
  // =========================
  const bg = "#0f0f10";
  const label = "#a9a9aa";
  const subtle = "#7c7c7d";
  const accent = "#ff7a00"; // HOY

  const pastWeekday = "#e9e9ea";
  const futureWeekday = "#2f2f31";

  const pastSaturday = "#cfcfd1";
  const futureSaturday = "#6b6b70";

  const sundayRed = "#ff3b30";
  // Si es domingo y cumple, oscurecemos el interior para que el anillo rojo se vea
  const sundayRedInnerWhenBirthday = "#b3261e";

  const birthdayRing = "#ff3b30"; // anillo cumples

  // Anillo claro para HOY (para diferenciar de domingo rojo)
  const todayHalo = "#f2f2f2";

  const barTrack = "#1b1b1d";

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
          {/* Months grid */}
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

                      // 0=Lun..6=Dom
                      const weekdayIndex = (startOffset + (dayNum - 1)) % 7;
                      const isSaturday = weekdayIndex === 5;
                      const isSunday = weekdayIndex === 6;

                      const dayDate = new Date(Date.UTC(year, month0, dayNum));
                      const isToday = dayDate.getTime() === todayMidnight.getTime();
                      const isPast = dayDate.getTime() < todayMidnight.getTime();

                      const mmdd = `${pad2(month0 + 1)}-${pad2(dayNum)}`;
                      const isBirthday = BIRTHDAYS.has(mmdd);

                      let fillBase: string;

                      if (isSunday) {
                        fillBase = isBirthday ? sundayRedInnerWhenBirthday : sundayRed;
                      } else if (isSaturday) {
                        fillBase = isPast ? pastSaturday : futureSaturday;
                      } else {
                        fillBase = isPast ? pastWeekday : futureWeekday;
                      }

                      // --- HOY: naranja con anillo claro (para que destaque sobre domingo rojo) ---
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
                          outerStyle.border = `${ring}px solid ${birthdayRing}`;
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

                      // --- NO hoy: bolita normal (+ anillo rojo si cumple) ---
                      let dotStyle: CSSProperties = {
                        display: "flex",
                        width: dot,
                        height: dot,
                        borderRadius: 999,
                        background: fillBase,
                        boxSizing: "border-box",
                      };

                      if (isBirthday) {
                        dotStyle = { ...dotStyle, border: `${ring}px solid ${birthdayRing}` };
                      }

                      return <div key={idx} style={dotStyle} />;
                    })}
                  </div>
                </div>
              );
            })}
          </div>

          <div style={{ display: "flex", height: footerGap }} />

          {/* Footer: days left + % */}
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

          {/* Barra */}
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
