import { ImageResponse } from "next/og";
import type { CSSProperties } from "react";

export const runtime = "edge";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Semana Lunes->Domingo
function monFirstIndex(utcDay: number) {
  // JS: getUTCDay(): 0=Dom ... 6=Sáb  -> queremos 0=Lun ... 6=Dom
  return (utcDay + 6) % 7;
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

  // iPhone 15 Pro Max recomendado
  const width = parseInt(searchParams.get("width") ?? "1290", 10);
  const height = parseInt(searchParams.get("height") ?? "2796", 10);

  // Pásalo desde Atajos como YYYY-MM-DD para refresco diario
  const dateParam = searchParams.get("date"); // "YYYY-MM-DD"
  const today = dateParam ? new Date(`${dateParam}T00:00:00Z`) : new Date();

  const year = today.getUTCFullYear();
  const todayMidnight = new Date(Date.UTC(year, today.getUTCMonth(), today.getUTCDate()));

  // Footer: “xd left · %”
  const totalDays = isLeapYear(year) ? 366 : 365;
  const doy = dayOfYearUTC(today);
  const daysLeft = totalDays - doy;
  const pct = Math.round((doy / totalDays) * 100);

  // =========================
  // LAYOUT (márgenes grandes)
  // =========================
  const topMargin = Math.round(height * 0.30); // aire arriba
  const bottomMargin = Math.round(height * 0.22); // aire abajo

  const contentW = Math.round(width * 0.72); // bloque más estrecho (como el ejemplo)
  const leftRight = Math.round((width - contentW) / 2);

  const colGap = Math.round(width * 0.06);
  const rowGap = Math.round(width * 0.055);

  const cols = 3;
  const monthW = Math.floor((contentW - colGap * (cols - 1)) / cols);

  // Dots para 7 columnas
  const dotGap = Math.max(10, Math.round(monthW * 0.06));
  const dot = Math.max(10, Math.floor((monthW - dotGap * 6) / 7));

  const labelFont = Math.max(18, Math.round(dot * 1.25));
  const labelH = Math.round(dot * 2.0);

  const dotsH = 6 * dot + 5 * dotGap; // 6 filas máx
  const monthH = labelH + dotsH;

  // Footer
  const footerGap = Math.round(height * 0.06);
  const footerFont = Math.max(22, Math.round(width * 0.04));

  // =========================
  // COLORES (modo oscuro)
  // =========================
  const bg = "#0f0f10";
  const label = "#a9a9aa";
  const subtle = "#7c7c7d";
  const accent = "#ff7a00";

  // Base
  const pastWeekday = "#e9e9ea";
  const futureWeekday = "#2f2f31";

  // Findes "con más color" (azulito)
  const pastWeekend = "#b9d6ff";   // más color sin ser chillón
  const futureWeekend = "#25324a"; // azul oscuro

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
        {/* Top margin */}
        <div style={{ display: "flex", height: topMargin }} />

        {/* Content block */}
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
              const paddedTotal = Math.ceil(total / 7) * 7; // semanas completas

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
                  {/* Month label */}
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

                  {/* Dots */}
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
                      const isWeekend = weekdayIndex === 5 || weekdayIndex === 6;

                      const dayDate = new Date(Date.UTC(year, month0, dayNum));
                      const isToday = dayDate.getTime() === todayMidnight.getTime();
                      const isPast = dayDate.getTime() < todayMidnight.getTime();

                      const fillBase = isPast
                        ? (isWeekend ? pastWeekend : pastWeekday)
                        : (isWeekend ? futureWeekend : futureWeekday);

                      // bolita normal
                      let dotStyle: CSSProperties = {
                        display: "flex",
                        width: dot,
                        height: dot,
                        borderRadius: 999,
                        background: fillBase,
                        boxSizing: "border-box",
                      };

                      // Hoy: naranja (como el ejemplo)
                      if (isToday) {
                        dotStyle = { ...dotStyle, background: accent };
                      }

                      return <div key={idx} style={dotStyle} />;
                    })}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Footer spacing */}
          <div style={{ display: "flex", height: footerGap }} />

          {/* Footer: 355d left · 2% */}
          <div
            style={{
              display: "flex",
              flexDirection: "row",
              justifyContent: "center",
              alignItems: "center",
              gap: Math.max(10, Math.round(footerFont * 0.4)),
              fontSize: footerFont,
              fontWeight: 700,
              letterSpacing: 0.2,
            }}
          >
            <div style={{ display: "flex", color: accent }}>{daysLeft}d left</div>
            <div style={{ display: "flex", color: subtle }}>·</div>
            <div style={{ display: "flex", color: subtle }}>{pct}%</div>
          </div>
        </div>

        {/* Bottom margin */}
        <div style={{ display: "flex", height: bottomMargin }} />
      </div>
    ),
    {
      width,
      height,
      headers: {
        "Cache-Control": "no-store",
      },
    }
  );
}
