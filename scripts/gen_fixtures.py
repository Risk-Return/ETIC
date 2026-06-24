#!/usr/bin/env python3
"""生成排盘引擎所需的「预设数据」与测试基准。

依赖：天文历算库 sxtwl（`pip install sxtwl`）。

产物：
  1. 二十四节气「节」日期表（写入 SolarTermTable.swift 的 rawRows）。
  2. 干支历换算测试基准（CalendarTests.swift 的 fixtures）。

这些数据是「确定性术数计算」的金标准来源：引擎在端上用纯 Swift 复现，
本脚本仅用于离线生成 / 校验，不参与 App 运行时。
"""
import sys

try:
    import sxtwl
except ImportError:
    sys.exit("需要 sxtwl：pip install sxtwl")

STEMS = "甲乙丙丁戊己庚辛壬癸"
BRANCHES = "子丑寅卯辰巳午未申酉戌亥"

FIRST_YEAR, LAST_YEAR = 1900, 2100


def gz(g):
    return STEMS[g.tg] + BRANCHES[g.dz]


def node_days_row(year):
    """该年 12 个「节」（公历各月节）的日。节气 index = 2*month - 1。"""
    days = []
    for m in range(1, 13):
        found = None
        for d in range(1, 32):
            try:
                day = sxtwl.fromSolar(year, m, d)
            except Exception:
                continue
            if day.hasJieQi() and day.getJieQi() == 2 * m - 1:
                found = d
                break
        assert found is not None, (year, m)
        days.append(found)
    return "".join("%02d" % d for d in days)


def print_solar_term_rows():
    print("// SolarTermTable.rawRows:")
    for year in range(FIRST_YEAR, LAST_YEAR + 1):
        print('        "%s", // %d' % (node_days_row(year), year))


def print_calendar_fixtures(cases):
    print("// CalendarTests.fixtures:")
    for (y, m, d, h) in cases:
        day = sxtwl.fromSolar(y, m, d)
        print('        Fixture(y: %d, m: %d, d: %d, h: %d, year: "%s", month: "%s", day: "%s", hour: "%s"),'
              % (y, m, d, h, gz(day.getYearGZ()), gz(day.getMonthGZ()),
                 gz(day.getDayGZ()), gz(day.getHourGZ(h))))


DEFAULT_CASES = [
    (2024, 2, 4, 12), (2024, 2, 3, 12), (2024, 2, 5, 0), (2025, 12, 21, 23),
    (2026, 3, 5, 18), (2026, 6, 24, 7), (2000, 1, 1, 0), (1984, 2, 2, 12),
    (1900, 1, 6, 10), (2100, 12, 7, 14), (2023, 8, 8, 9), (2023, 8, 7, 3),
    (2025, 1, 5, 5), (2025, 1, 6, 5), (1995, 5, 15, 16), (2010, 10, 10, 10),
    (2026, 2, 4, 1), (2026, 2, 3, 1), (1988, 11, 7, 22), (2047, 7, 7, 7),
]


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "terms"):
        print_solar_term_rows()
    if what in ("all", "fixtures"):
        print_calendar_fixtures(DEFAULT_CASES)
