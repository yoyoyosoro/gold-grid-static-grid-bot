//+------------------------------------------------------------------+
//|                                          StaticGridBot v4.06.mq5 |
//|                                      Gold Investor Research 专属 |
//|                                      实盘双核版 v4.06             |
//+------------------------------------------------------------------+
#property copyright "Gold Investor Research"
#property link      ""
#property version   "4.06"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// [1] 基础交易与魔术数参数
//====================================================================
input group "=== 1. 基础交易与魔术数参数 ===";
input ulong    InpBaseMagic         = 1;          // 初始大底仓专属魔术数
input ulong    InpBaseGridMagic     = 5;          // 底仓回补碎单专属魔术数
input ulong    InpDownMagic         = 2;          // 下方抄底碎单专属魔术数
input ulong    InpBaseMergedMagic   = 3;          // 底仓回补合并仓专属魔术数
input ulong    InpDownMergedMagic   = 4;          // 密网体系合并仓专属魔术数
input double   InpMinLot            = 0.01;       // 上方底仓手数与切分单位；区间1手数设0时沿用

//====================================================================
// [1.1] EA 运行模式
//====================================================================
input group "=== 1.1 EA运行模式 ===";
input bool     InpPureDenseMode     = false;      // true=仅运行下方密网，不建立初始底仓

//====================================================================
// [2] 系统 1：上方底仓系统
//====================================================================
input group "=== 2. 系统 1：上方底仓系统 ===";
input double   InpCustomBasePrice   = 0.0;        // 潜伏狙击点：到达此点位才建底仓 (0为直接开启)
input double   InpBaseUpperLimit    = 0.0;        // 上方底仓系统最高价；普通模式必须大于 0
input int      InpBaseGridPoints    = 1000;       // 回补间距（报价点数；距离=点数×_Point，随报价位数自适应）
input int      InpBaseTakeProfit    = 1000;       // 回补单止盈距离（报价点数；距离=点数×_Point）

input group "=== 2.1 EA 完全结算退出 ===";
input double   InpEAExitPrice       = 0.0;        // EA完全结算退出价；0=不启用价格触发退出

//====================================================================
// [3] 系统 2：下方密集网格系统
//====================================================================
input group "=== 3.1 密网区间1（兼容原密网） ===";
input bool     InpDownEnabled       = true;       // 启用区间1
input double   InpDownLot           = 0.0;        // 区间1手数（0=沿用原基础手数）
input double   InpDownUpperLimit    = 0.0;        // 密集网格顶部界限 (设0则智能跟随)
input double   InpDownLowerLimit    = 4000.00;    // 网格铺设下限：仅过滤候选挂单目标价
input int      InpDownGridPoints    = 300;        // 买入间距（报价点数；距离=点数×_Point，随报价位数自适应）
input int      InpDownTakeProfit    = 500;        // 散单止盈距离（报价点数；距离=点数×_Point）
input int      InpMaxGridLevels     = 20;         // 区间1动态候选层数
input bool     InpDownDraw          = true;       // 显示区间1顶底线
input color    InpDownColor         = clrDodgerBlue; // 区间1线色
input int      InpDownWidth         = 1;          // 区间1线宽（1-5）
input ENUM_LINE_STYLE InpDownStyle  = STYLE_DASH; // 区间1线型

input group "=== 3.2 密网区间2 ===";
input bool     InpDown2Enabled     = false;       // 启用区间2
input ulong    InpDown2Magic       = 6;           // 区间2碎单 Magic
input ulong    InpDown2MergedMagic = 7;           // 区间2合并 Magic
input double   InpDown2UpperLimit  = 0.0;         // 区间2顶部（0=智能跟随）
input double   InpDown2LowerLimit  = 4000.0;      // 区间2底部
input double   InpDown2Lot         = 0.01;        // 区间2手数
input int      InpDown2GridPoints  = 300;         // 区间2间距（报价点）
input int      InpDown2TakeProfit  = 500;         // 区间2止盈（报价点）
input int      InpDown2MaxLevels   = 20;          // 区间2动态候选层数
input bool     InpDown2Draw        = true;        // 显示区间2顶底线
input color    InpDown2Color       = clrOrangeRed; // 区间2线色
input int      InpDown2Width       = 1;           // 区间2线宽（1-5）
input ENUM_LINE_STYLE InpDown2Style = STYLE_DASH; // 区间2线型

input group "=== 3.3 密网区间3 ===";
input bool     InpDown3Enabled     = false;       // 启用区间3
input ulong    InpDown3Magic       = 8;           // 区间3碎单 Magic
input ulong    InpDown3MergedMagic = 9;           // 区间3合并 Magic
input double   InpDown3UpperLimit  = 0.0;         // 区间3顶部（0=智能跟随）
input double   InpDown3LowerLimit  = 4000.0;      // 区间3底部
input double   InpDown3Lot         = 0.01;        // 区间3手数
input int      InpDown3GridPoints  = 300;          // 区间3间距（报价点）
input int      InpDown3TakeProfit  = 500;          // 区间3止盈（报价点）
input int      InpDown3MaxLevels   = 20;           // 区间3动态候选层数
input bool     InpDown3Draw        = true;         // 显示区间3顶底线
input color    InpDown3Color       = clrMediumSeaGreen; // 区间3线色
input int      InpDown3Width       = 1;            // 区间3线宽（1-5）
input ENUM_LINE_STYLE InpDown3Style = STYLE_DASH;  // 区间3线型

//====================================================================
// [4] 风控面板与排版参数 (UI定制)
//====================================================================
input group "=== 4. 风控与面板面板参数 ===";
input double   InpPsyStopOutLevel   = 3000.00;    // 心理防爆仓底线 (用于推演 ⑥ ⑦)
input int      InpPanelX            = 600;        // UI 面板X轴偏移量 (向左推，加大防裁切)
input int      InpPanelY            = 20;         // UI 面板Y轴偏移量 (向下推)
input int      InpPanelFontSize     = 11;         // UI 面板字号大小

//====================================================================
// [5] 其它细节参数
//====================================================================
input group "=== 5. 细节偏移与合并阈值 ===";
input int      InpOffsetPoints      = 0;          // 挂单整数偏移量（报价点数）
input int      InpMergeThreshold    = 30;         // 每批严格合并的碎单数量
input int      InpEmergencyLimit    = 180;        // 紧急扫描警戒线（不改变每批合并数量）

struct DenseRegion
{
    bool enabled;
    ulong magic;
    ulong mergedMagic;
    double top;
    double bottom;
    double lot;
    int points;
    int takeProfit;
    int levels;
    bool draw;
    color lineColor;
    int width;
    ENUM_LINE_STYLE style;
    int sliceLevel;
    string stateKey;
};
DenseRegion regions[3];
string linePrefix;
string targetPrefix;
string regionStatePrefix;
int sliceActionsThisTick = 0;

void ConfigureRegion(int r, bool enabled, ulong magic, ulong mergedMagic,
                     double top, double bottom, double lot, int points, int tp, int levels,
                     bool draw, color lineColor, int width, ENUM_LINE_STYLE style)
{
    regions[r].enabled = enabled;
    regions[r].magic = magic;
    regions[r].mergedMagic = mergedMagic;
    regions[r].top = top;
    regions[r].bottom = bottom;
    regions[r].lot = lot;
    regions[r].points = points;
    regions[r].takeProfit = tp;
    regions[r].levels = levels;
    regions[r].draw = draw;
    regions[r].lineColor = lineColor;
    regions[r].width = width;
    regions[r].style = style;
    regions[r].sliceLevel = -999999;
}

void ConfigureRegions()
{
    ConfigureRegion(0, InpDownEnabled, InpDownMagic, InpDownMergedMagic,
                    InpDownUpperLimit, InpDownLowerLimit, InpDownLot == 0 ? InpMinLot : InpDownLot,
                    InpDownGridPoints, InpDownTakeProfit, InpMaxGridLevels,
                    InpDownDraw, InpDownColor, InpDownWidth, InpDownStyle);
    ConfigureRegion(1, InpDown2Enabled, InpDown2Magic, InpDown2MergedMagic,
                    InpDown2UpperLimit, InpDown2LowerLimit, InpDown2Lot,
                    InpDown2GridPoints, InpDown2TakeProfit, InpDown2MaxLevels,
                    InpDown2Draw, InpDown2Color, InpDown2Width, InpDown2Style);
    ConfigureRegion(2, InpDown3Enabled, InpDown3Magic, InpDown3MergedMagic,
                    InpDown3UpperLimit, InpDown3LowerLimit, InpDown3Lot,
                    InpDown3GridPoints, InpDown3TakeProfit, InpDown3MaxLevels,
                    InpDown3Draw, InpDown3Color, InpDown3Width, InpDown3Style);
}

int RegionForMagic(ulong magic)
{
    for(int r = 0; r < 3; r++)
        if(magic == regions[r].magic || magic == regions[r].mergedMagic) return r;
    return -1;
}

bool IsDenseSourceMagic(ulong magic)
{
    int r = RegionForMagic(magic);
    return r >= 0 && magic == regions[r].magic;
}

bool IsDenseMergedMagic(ulong magic)
{
    int r = RegionForMagic(magic);
    return r >= 0 && magic == regions[r].mergedMagic;
}

//--- 全局变量 ---
double GlobalStartPrice = 0;       // 0=潜伏, -1=纯密网模式, >0=已确立底仓
string gvName;
string legacyGvName;
string gvUpperSliceName;
string gvDenseSliceName;
string gvExitName;
string mergeStateScope;
bool   exitInProgress = false;
static double lastBidLower = 0;
static int    highestSlicedLevelUp = -999999;
static int    lastSlicedLevelDn = -999999;

const int UNINITIALIZED_LEVEL = -999999;
const int MAX_SLICE_ACTIONS_PER_TICK = 20;
const int MERGE_PENDING_CLOSING = 1;
const int MERGE_PENDING_OPENING = 2;
const int MERGE_PENDING_OPENED_UNBOUND = 3;
const int MERGE_FRAGMENT_PENDING      = 0;
const int MERGE_FRAGMENT_CLOSED_BY_EA = 1;
const int MERGE_FRAGMENT_CLOSED_AT_TP = 2;
const int MERGE_FRAGMENT_EXIT_UNKNOWN = -1;

struct MergeFragment
{
    long   positionIdentifier;
    long   openedAt;
    double volume;
    double targetPrice;
};

// 合并批次函数在文件末尾集中实现；这里声明供启动、TP、切分和挂单管理调用。
void ClearAllMergeStateScope();
bool HasPendingMerge(ulong sourceMagic);
bool HasActiveMergeState(ulong mergedMagic, long positionIdentifier);
void ProcessPendingMergePlans();
void ProcessMergedBatchSplits();

//--- 官方引擎静态缓存变量 ---
static double cachedReferenceLot  = 0;     // 本轮官方计算使用的有效参考手数
static double cachedMarginPerLot  = 0;     // 换算后的每手保证金 (单位: 账户基准)
static double cachedProfitPerLot  = 0;     // 换算后的每手波动 1 美元盈亏
static double cachedBasePrice     = 0;     // 缓存时的基准价格
static datetime lastCacheUpdateTime = 0;   // 最近一次成功更新时间
static datetime lastCacheAttemptTime = 0;  // 最近一次尝试时间，失败时避免逐 tick 刷屏
static int    cachedRiskErrorCode = 0;
static bool   cachedRiskDataValid = false;
static int    cachedMarginSource = 0;       // 1=OrderCalcMargin，2=OrderCheck 增量保证金
static bool   cachedMarginFreeMode = false; // 经纪商确认的有效零保证金模式
static bool   positionAuditLogged = false;  // 每次加载只输出一次同 tick 持仓对账

//+------------------------------------------------------------------+
//| 订单范围、参数校验与持久状态                                    |
//+------------------------------------------------------------------+
bool IsManagedMagic(ulong magic)
{
    return IsBaseSystemMagic(magic) || RegionForMagic(magic) >= 0;
}

bool IsBaseSystemMagic(ulong magic)
{
    return (magic == InpBaseMagic || magic == InpBaseGridMagic || magic == InpBaseMergedMagic);
}

bool IsMergedMagic(ulong magic)
{
    return magic == InpBaseMergedMagic || IsDenseMergedMagic(magic);
}

double VolumeTolerance()
{
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    return MathMax(0.000001, step * 0.1);
}

bool IsBrokerVolumeValid(double volume)
{
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(minLot <= 0 || maxLot < minLot || step <= 0) return false;

    double tolerance = MathMax(0.0000001, step * 0.0001);
    if(volume < minLot - tolerance || volume > maxLot + tolerance) return false;

    double aligned = MathRound(volume / step) * step;
    return MathAbs(volume - aligned) <= tolerance;
}

bool IsTradeRetcodeSuccessful()
{
    uint code = trade.ResultRetcode();
    return (code == TRADE_RETCODE_DONE || code == TRADE_RETCODE_DONE_PARTIAL ||
            code == TRADE_RETCODE_PLACED || code == TRADE_RETCODE_NO_CHANGES);
}

bool ConfirmTradeResult(bool sent, string action, ulong ticket)
{
    if(sent && IsTradeRetcodeSuccessful()) return true;

    PrintFormat("交易失败：%s，ticket=%I64u，retcode=%u，%s",
                action, ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
    return false;
}

bool RejectInvalidInput(string reason)
{
    Alert("参数错误：", reason, "。EA 未启动，未执行任何删单或交易动作。");
    Print("参数错误：", reason);
    return false;
}

bool IsBaseUpperLimitValid(double baseUpperLimit, bool pureDenseMode)
{
    if(!MathIsValidNumber(baseUpperLimit) || baseUpperLimit < 0) return false;
    return pureDenseMode || baseUpperLimit > 0;
}

bool ValidateInputs()
{
    if(!IsBaseUpperLimitValid(InpBaseUpperLimit, InpPureDenseMode))
        return RejectInvalidInput(InpPureDenseMode ?
                                  "上方底仓系统最高价不能小于 0" :
                                  "普通模式下上方底仓系统最高价必须大于 0");
    if(!MathIsValidNumber(InpEAExitPrice) || InpEAExitPrice < 0)
        return RejectInvalidInput("EA完全结算退出价不能小于 0");
    if(InpCustomBasePrice < 0 || InpBaseGridPoints <= 0 || InpBaseTakeProfit <= 0 ||
       InpMergeThreshold <= 0 || InpEmergencyLimit <= 0)
        return RejectInvalidInput("底仓价格、间距、止盈或合并阈值无效");
    if(!IsBrokerVolumeValid(InpMinLot) || InpMinLot < 0.01 ||
       MathAbs(InpMinLot * 100.0 - MathRound(InpMinLot * 100.0)) > 0.000001)
        return RejectInvalidInput("基础手数须符合交易规格并按 0.01 递增");
    if(!MathIsValidNumber(InpPsyStopOutLevel) || InpPsyStopOutLevel <= 0)
        return RejectInvalidInput("心理防线必须大于 0");

    ulong magics[9] = {InpBaseMagic, InpBaseGridMagic, InpBaseMergedMagic,
                      regions[0].magic, regions[0].mergedMagic,
                      regions[1].magic, regions[1].mergedMagic,
                      regions[2].magic, regions[2].mergedMagic};
    for(int i = 0; i < 9; i++)
    {
        // 合并状态使用 double 保存 Magic，限制在精确整数范围内。
        if(magics[i] == 0 || magics[i] > 9007199254740991)
            return RejectInvalidInput("Magic 必须为 1 至 9007199254740991 的整数");
        for(int j = i + 1; j < 9; j++)
            if(magics[i] == magics[j]) return RejectInvalidInput("九个 Magic 不能重复");
    }
    for(int r = 0; r < 3; r++)
    {
        if(!regions[r].enabled) continue;
        string label = StringFormat("区间%d：", r + 1);
        if(!MathIsValidNumber(regions[r].top) || !MathIsValidNumber(regions[r].bottom) ||
           regions[r].bottom <= 0 || regions[r].top < 0 ||
           (InpBaseUpperLimit > 0 && InpBaseUpperLimit <= regions[r].bottom) ||
           (InpPureDenseMode && InpBaseUpperLimit <= 0 && regions[r].top <= 0) ||
           (regions[r].top > 0 && regions[r].top <= regions[r].bottom))
        {
            if(InpPureDenseMode && InpBaseUpperLimit <= 0 && regions[r].top <= 0)
                return RejectInvalidInput(label + "必须填写大于 0 的顶部；仅运行密网且底仓最高价为 0 时不能使用智能跟随");
            return RejectInvalidInput(label + "顶底价格无效");
        }
        if(regions[r].points <= 0 || regions[r].takeProfit <= 0 || regions[r].levels <= 0)
            return RejectInvalidInput(label + "间距、止盈、层数必须大于 0");
        if(!IsBrokerVolumeValid(regions[r].lot) || regions[r].lot < 0.01 ||
           MathAbs(regions[r].lot * 100 - MathRound(regions[r].lot * 100)) > 0.000001)
            return RejectInvalidInput(label + "手数须符合交易规格并按 0.01 递增");
        if(regions[r].width < 1 || regions[r].width > 5)
            return RejectInvalidInput(label + "线宽必须为 1 至 5");
    }
    return true;
}

bool IsEAExitTriggered(double bid, double exitPrice)
{
    return exitPrice > 0 && bid >= exitPrice;
}

void InitializeStateNames()
{
    legacyGvName = "GoldGrid_StartPrice_" + _Symbol;
    string scope = "GoldGrid_v398_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) +
                   "_" + _Symbol + "_" + IntegerToString((long)InpBaseMagic) +
                   "_" + IntegerToString((long)InpDownMagic) +
                   "_" + IntegerToString((long)InpBaseMergedMagic) +
                   "_" + IntegerToString((long)InpDownMergedMagic);
    gvName             = scope + "_StartPrice";
    gvUpperSliceName   = scope + "_UpperSliceLevel";
    gvDenseSliceName   = scope + "_DenseSliceLevel";
    gvExitName         = scope + "_ExitInProgress";
    regionStatePrefix = "D405_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + _Symbol + "_";
    targetPrefix = "T405_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + _Symbol + "_";
    linePrefix = "Grid405_" + IntegerToString(ChartID()) + "_";
    for(int r = 0; r < 3; r++)
        regions[r].stateKey = regionStatePrefix + StringFormat("%I64u_", regions[r].magic);

    // 沿用 v4.00 状态命名，避免升级时丢失仍在管理的密网合并阶梯；
    // 新增的回补碎单 Magic 会继续写入每个合并计划自身的键名。
    mergeStateScope = "G99_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) +
                      "_" + _Symbol + "_" + IntegerToString((long)InpBaseMagic) +
                      "_" + IntegerToString((long)InpDownMagic) +
                      "_" + IntegerToString((long)InpBaseMergedMagic) +
                      "_" + IntegerToString((long)InpDownMergedMagic);
}

void SaveStartPrice()
{
    GlobalVariableSet(gvName, GlobalStartPrice);
}

void SaveUpperSliceLevel()
{
    GlobalVariableSet(gvUpperSliceName, (double)highestSlicedLevelUp);
}

void SaveDenseSliceLevel()
{
    GlobalVariableSet(gvDenseSliceName, (double)lastSlicedLevelDn);
}

void ClearCycleState(bool clearManagedStates = true)
{
    if(GlobalVariableCheck(gvName)) GlobalVariableDel(gvName);
    if(GlobalVariableCheck(gvUpperSliceName)) GlobalVariableDel(gvUpperSliceName);
    if(clearManagedStates && GlobalVariableCheck(gvDenseSliceName)) GlobalVariableDel(gvDenseSliceName);
    if(GlobalVariableCheck(gvExitName)) GlobalVariableDel(gvExitName);
    if(GlobalVariableCheck(legacyGvName)) GlobalVariableDel(legacyGvName);
    if(clearManagedStates)
    {
        ClearAllMergeStateScope();
        for(int r = 0; r < 3; r++)
        {
            GlobalVariablesDeleteAll(regions[r].stateKey);
            GlobalVariablesDeleteAll(targetPrefix + StringFormat("%I64u_", regions[r].magic));
        }
    }

    GlobalStartPrice = 0;
    highestSlicedLevelUp = UNINITIALIZED_LEVEL;
    lastSlicedLevelDn = UNINITIALIZED_LEVEL;
    lastBidLower = 0;
    exitInProgress = false;
}

void LoadCycleState(double bid)
{
    GlobalStartPrice = 0;
    highestSlicedLevelUp = UNINITIALIZED_LEVEL;
    lastSlicedLevelDn = UNINITIALIZED_LEVEL;
    exitInProgress = false;

    if(GlobalVariableCheck(gvName))
    {
        GlobalStartPrice = GlobalVariableGet(gvName);
    }
    else if(GlobalVariableCheck(legacyGvName))
    {
        GlobalStartPrice = GlobalVariableGet(legacyGvName);
        SaveStartPrice();
        GlobalVariableDel(legacyGvName);
        Print("已将 v3.97 起始价便签迁移至 v3.98 的账户与 Magic 隔离状态。");
    }

    if(GlobalVariableCheck(gvUpperSliceName))
        highestSlicedLevelUp = (int)MathRound(GlobalVariableGet(gvUpperSliceName));
    if(GlobalVariableCheck(gvDenseSliceName))
        lastSlicedLevelDn = (int)MathRound(GlobalVariableGet(gvDenseSliceName));
    if(GlobalVariableCheck(gvExitName) && GlobalVariableGet(gvExitName) > 0.5)
        exitInProgress = true;

    double off = (double)InpOffsetPoints * _Point;
    if(GlobalStartPrice > 0 && highestSlicedLevelUp == UNINITIALIZED_LEVEL)
    {
        highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - off) / ((double)InpBaseGridPoints * _Point));
        SaveUpperSliceLevel();
        Print("未找到上方切分进度，已从底仓起点建立 v3.98 补切基线。");
    }
    // 各区间的补切基线在起始价协调后单独恢复。
    lastBidLower = bid;
}

bool HasBaseSystemPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
           IsBaseSystemMagic(PositionGetInteger(POSITION_MAGIC))) return true;
    }
    return false;
}

double FindActualBaseAnchor()
{
    double candidate = 0;
    long candidateTime = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpBaseMagic)
            continue;

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        if(GlobalStartPrice > 0 && MathAbs(openPrice - GlobalStartPrice) < 2.0)
            return openPrice;

        long openedAt = PositionGetInteger(POSITION_TIME_MSC);
        if(candidate == 0 || openedAt < candidateTime)
        {
            candidate = openPrice;
            candidateTime = openedAt;
        }
    }
    return candidate;
}

void ReconcileStartState()
{
    if(exitInProgress) return;
    if(GlobalStartPrice == -1)
    {
        if(!InpPureDenseMode)
        {
            Print("纯密网便签与当前开关不一致，自动清除旧便签并按普通模式重新判定启动条件。");
            ClearCycleState(false);
        }
        return;
    }
    if(GlobalStartPrice <= 0) return;

    if(!HasBaseSystemPosition())
    {
        Print("未找到与起始价便签对应的底仓体系持仓，自动删除陈旧便签。");
        ClearCycleState(false);
        return;
    }

    double actualAnchor = FindActualBaseAnchor();
    if(actualAnchor > 0 && MathAbs(actualAnchor - GlobalStartPrice) >= 2.0)
    {
        GlobalStartPrice = actualAnchor;
        highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - (double)InpOffsetPoints * _Point) /
                                               ((double)InpBaseGridPoints * _Point));
        SaveStartPrice();
        SaveUpperSliceLevel();
        Print("真实底仓与旧便签不一致，已自动以实际底仓价格重建起始价状态：", GlobalStartPrice);
    }
}

//+------------------------------------------------------------------+
//| EA 卸载清理函数                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "RPL_");
    ObjectsDeleteAll(0, "RiskPanelLine_");
    if(linePrefix != "") ObjectsDeleteAll(0, linePrefix);
    Print("EA已卸载或参数变更，正在清理屏幕残影UI...");
}

//+------------------------------------------------------------------+
//| 获取底仓系统的基准下限 (物理网格线对齐)                          |
//+------------------------------------------------------------------+
double GetBaseAnchor()
{
    if(GlobalStartPrice <= 0) return 0;
    double off = (double)InpOffsetPoints * _Point;
    double step = (double)InpBaseGridPoints * _Point;
    return MathFloor((GlobalStartPrice - off) / step) * step + off;
}

//+------------------------------------------------------------------+
//| 获取密网系统的智能上限                                           |
//+------------------------------------------------------------------+
double GetDenseGridTop(int r = 0)
{
    if(regions[r].top > 0) return regions[r].top;
    if(GlobalStartPrice > 0) return GetBaseAnchor();
    return InpBaseUpperLimit;
}

bool DensePriceAllowed(int r, double price)
{
    return price >= regions[r].bottom && price < GetDenseGridTop(r) - 0.001;
}

double DenseCandidatePrice(int r, double ask, int level)
{
    double step = regions[r].points * _Point;
    return NormalizeDouble(MathFloor(ask / step) * step - level * step +
                           InpOffsetPoints * _Point, _Digits);
}

bool DenseCandidateAllowed(int r, double ask, double price)
{
    return regions[r].enabled && DensePriceAllowed(r, price) &&
           ask - price >= regions[r].points * _Point;
}

void SaveRegionSlice(int r)
{
    GlobalVariableSet(regions[r].stateKey + "L", regions[r].sliceLevel);
    if(r == 0)
    {
        lastSlicedLevelDn = regions[r].sliceLevel;
        SaveDenseSliceLevel();
    }
}

void LoadRegionSlices(double bid)
{
    double off = InpOffsetPoints * _Point;
    for(int r = 0; r < 3; r++)
    {
        string key = regions[r].stateKey;
        // 停用只停止建仓，保存的管理间距仍供遗留持仓使用。
        if(!regions[r].enabled && GlobalVariableCheck(key + "P"))
        {
            regions[r].points = (int)GlobalVariableGet(key + "P");
            regions[r].top = GlobalVariableGet(key + "T");
            regions[r].bottom = GlobalVariableGet(key + "B");
        }
        if(regions[r].points <= 0) continue;
        int level = (int)MathFloor((bid - off) / (regions[r].points * _Point));
        bool hasGeometry = GlobalVariableCheck(key + "P") && GlobalVariableCheck(key + "O");
        bool sameGeometry = hasGeometry &&
                            GlobalVariableGet(key + "P") == regions[r].points &&
                            GlobalVariableGet(key + "O") == InpOffsetPoints;
        if(sameGeometry && GlobalVariableCheck(key + "L"))
            level = (int)GlobalVariableGet(key + "L");
        else if(!hasGeometry && r == 0 && GlobalVariableCheck(gvDenseSliceName))
            level = (int)GlobalVariableGet(gvDenseSliceName);
        regions[r].sliceLevel = level;
        GlobalVariableSet(key + "P", regions[r].points);
        GlobalVariableSet(key + "O", InpOffsetPoints);
        GlobalVariableSet(key + "T", regions[r].top);
        GlobalVariableSet(key + "B", regions[r].bottom);
        SaveRegionSlice(r);
    }
    string key = regionStatePrefix + "U_" + StringFormat("%I64u_", InpBaseMagic);
    if(GlobalVariableCheck(key + "P") &&
       (GlobalVariableGet(key + "P") != InpBaseGridPoints ||
        GlobalVariableGet(key + "O") != InpOffsetPoints))
    {
        highestSlicedLevelUp = (int)MathFloor((bid - off) / (InpBaseGridPoints * _Point));
        SaveUpperSliceLevel();
    }
    GlobalVariableSet(key + "P", InpBaseGridPoints);
    GlobalVariableSet(key + "O", InpOffsetPoints);
}

void UpdateRegionLines()
{
    for(int r = 0; r < 3; r++)
    {
        for(int edge = 0; edge < 2; edge++)
        {
            string name = linePrefix + IntegerToString(r + 1) + (edge == 0 ? "_Top" : "_Bottom");
            double price = edge == 0 ? GetDenseGridTop(r) : regions[r].bottom;
            if(!regions[r].enabled || !regions[r].draw || price <= 0)
            {
                ObjectDelete(0, name);
                continue;
            }
            if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
            ObjectSetDouble(0, name, OBJPROP_PRICE, price);
            ObjectSetInteger(0, name, OBJPROP_COLOR, regions[r].lineColor);
            // 原生虚线只在宽度 1 时生效；实线使用设置的宽度。
            ObjectSetInteger(0, name, OBJPROP_WIDTH, regions[r].style == STYLE_SOLID ? regions[r].width : 1);
            ObjectSetInteger(0, name, OBJPROP_STYLE, regions[r].style);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
            ObjectSetString(0, name, OBJPROP_TEXT, StringFormat("区间%d %s", r + 1, edge == 0 ? "顶部" : "底部"));
        }
    }
}

string DenseTargetKey(ulong magic, long identifier)
{
    return targetPrefix + StringFormat("%I64u_%I64d", magic, identifier);
}

// 只在首次识别持仓时取目标；重载和改参后不使用新的 TP 输入覆盖旧目标。
double RememberDenseTarget()
{
    ulong magic = PositionGetInteger(POSITION_MAGIC);
    long identifier = PositionGetInteger(POSITION_IDENTIFIER);
    string key = DenseTargetKey(magic, identifier);
    if(GlobalVariableCheck(key)) return GlobalVariableGet(key);
    double target = PositionGetDouble(POSITION_TP);
    if(target <= 0 && HistorySelectByPosition(identifier))
    {
        for(int i = 0; i < HistoryDealsTotal(); i++)
        {
            ulong deal = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            ulong order = HistoryDealGetInteger(deal, DEAL_ORDER);
            if(HistoryOrderSelect(order)) target = HistoryOrderGetDouble(order, ORDER_TP);
            if(target > 0) break;
        }
    }
    if(target > 0 && MathIsValidNumber(target))
    {
        if(GlobalVariableSet(key, target) != 0) return target;
        PrintFormat("原始 TP 保存失败，持仓 ID=%I64d，错误=%d", identifier, GetLastError());
        return 0;
    }
    if(!GlobalVariableCheck(key + "W"))
    {
        PrintFormat("持仓 ID=%I64d 缺少可恢复的原始 TP；保留持仓，不按新参数补造目标。", identifier);
        GlobalVariableSet(key + "W", 1);
    }
    return 0;
}

//+------------------------------------------------------------------+
//| 官方底层引擎缓存系统 (彻底统一美分与美元单位)                    |
//+------------------------------------------------------------------+
double GetRiskReferenceLot()
{
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(minLot <= 0 || maxLot < minLot || step <= 0) return 0;

    double aligned = MathRound(minLot / step) * step;
    if(aligned + VolumeTolerance() < minLot) aligned += step;
    if(aligned <= 0 || aligned > maxLot + VolumeTolerance()) return 0;
    return NormalizeDouble(aligned, 8);
}

void InvalidateRiskCache(int errorCode, double referenceLot, double currentAsk)
{
    cachedReferenceLot  = referenceLot;
    cachedMarginPerLot  = 0;
    cachedProfitPerLot  = 0;
    cachedBasePrice     = 0;
    cachedRiskErrorCode = errorCode;
    cachedRiskDataValid = false;
    cachedMarginSource  = 0;
    cachedMarginFreeMode = false;
    PrintFormat("风控缓存计算失败：error=%d，symbol=%s，referenceLot=%.8f，price=%s",
                errorCode, _Symbol, referenceLot, DoubleToString(currentAsk, _Digits));
}

ENUM_ORDER_TYPE_FILLING GetRiskCheckFillingMode()
{
    uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
    if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
    return ORDER_FILLING_RETURN;
}

// OrderCheck 只做服务端预检，不发送订单。result.margin 是预检成交后的账户总保证金，
// 因此必须减去预检前的 ACCOUNT_MARGIN，得到本次参考手数的新增保证金。
bool TryOrderCheckMargin(double referenceLot, double currentAsk,
                         double &marginIncrement, bool &checkOk, uint &checkRetcode,
                         int &checkError, double &accountMarginBefore,
                         double &accountMarginAfter, string &checkComment)
{
    MqlTradeRequest request = {};
    MqlTradeCheckResult result = {};

    request.action       = TRADE_ACTION_DEAL;
    request.magic        = InpDownMagic;
    request.symbol       = _Symbol;
    request.volume       = referenceLot;
    request.type         = ORDER_TYPE_BUY;
    request.price        = NormalizeDouble(currentAsk, _Digits);
    request.type_filling = GetRiskCheckFillingMode();
    request.comment      = "RiskMarginCheck";

    accountMarginBefore = AccountInfoDouble(ACCOUNT_MARGIN);
    ResetLastError();
    checkOk = OrderCheck(request, result);
    checkError = (int)GetLastError();
    checkRetcode = result.retcode;
    accountMarginAfter = result.margin;
    checkComment = result.comment;
    marginIncrement = accountMarginAfter - accountMarginBefore;

    return checkOk && MathIsValidNumber(accountMarginBefore) &&
           MathIsValidNumber(accountMarginAfter) && MathIsValidNumber(marginIncrement) &&
           accountMarginBefore >= 0 && accountMarginAfter > accountMarginBefore &&
           marginIncrement > 0;
}

void UpdateEngineCache(double currentAsk)
{
    datetime now = TimeCurrent();
    if(cachedRiskDataValid && now - lastCacheUpdateTime < 1800) return;
    if(!cachedRiskDataValid && now - lastCacheAttemptTime < 60) return;
    lastCacheAttemptTime = now;

    double referenceLot = GetRiskReferenceLot();
    if(referenceLot <= 0 || currentAsk <= 1.0)
    {
        InvalidateRiskCache(-1, referenceLot, currentAsk);
        return;
    }

    double margin = 0;
    double profit = 0;

    ResetLastError();
    bool marginOk = OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, referenceLot, currentAsk, margin);
    int marginError = (int)GetLastError();

    ResetLastError();
    bool profitOk = OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, referenceLot,
                                    currentAsk, currentAsk - 1.0, profit);
    int profitError = (int)GetLastError();

    // 对当前 XAUUSDc，服务器可能在无限/免保证金模式下合法返回 0。
    // 只有 API 失败、非有限值或负值才算保证金计算失败。
    bool marginUsable = marginOk && MathIsValidNumber(margin) && margin >= 0;
    bool profitUsable = profitOk && MathIsValidNumber(profit) && MathAbs(profit) > 0;
    int marginSource = marginUsable ? 1 : 0;

    bool checkOk = false;
    uint checkRetcode = 0;
    int checkError = 0;
    double accountMarginBefore = 0;
    double accountMarginAfter = 0;
    double checkedMargin = 0;
    string checkComment = "未调用";

    if(!marginUsable)
    {
        bool fallbackUsable = TryOrderCheckMargin(referenceLot, currentAsk, checkedMargin,
                                                  checkOk, checkRetcode, checkError,
                                                  accountMarginBefore, accountMarginAfter,
                                                  checkComment);
        PrintFormat("保证金备用预检：ok=%s，retcode=%u，error=%d，before=%.8f，after=%.8f，increment=%.8f，comment=%s",
                    (checkOk ? "true" : "false"), checkRetcode, checkError,
                    accountMarginBefore, accountMarginAfter, checkedMargin, checkComment);
        if(fallbackUsable)
        {
            margin = checkedMargin;
            marginUsable = true;
            marginSource = 2;
        }
    }

    PrintFormat("风控基准诊断：symbol=%s，currency=%s，referenceLot=%.8f，price=%s，marginOk=%s，margin=%.8f，marginError=%d，profitOk=%s，profit=%.8f，profitError=%d，calcMode=%d，accountMarginMode=%d，leverage=%I64d",
                _Symbol, AccountInfoString(ACCOUNT_CURRENCY), referenceLot,
                DoubleToString(currentAsk, _Digits), (marginOk ? "true" : "false"), margin,
                marginError, (profitOk ? "true" : "false"), profit, profitError,
                (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE),
                (int)AccountInfoInteger(ACCOUNT_MARGIN_MODE),
                AccountInfoInteger(ACCOUNT_LEVERAGE));

    if(!marginUsable || !profitUsable)
    {
        int errorCode = -2;
        if(!marginOk && marginError != 0) errorCode = marginError;
        else if(!profitOk && profitError != 0) errorCode = profitError;
        else if(marginUsable && !profitUsable) errorCode = -3;
        InvalidateRiskCache(errorCode, referenceLot, currentAsk);
        return;
    }

    // 两个官方计算均成功后一次性提交，禁止半份缓存继续参与风险推演。
    cachedReferenceLot  = referenceLot;
    cachedMarginPerLot  = margin / referenceLot;
    cachedProfitPerLot  = MathAbs(profit) / referenceLot;
    cachedBasePrice     = currentAsk;
    cachedRiskErrorCode = 0;
    cachedRiskDataValid = true;
    cachedMarginSource  = marginSource;
    cachedMarginFreeMode = (margin == 0);
    lastCacheUpdateTime = now;
    PrintFormat("底层引擎已同步：参考 %.8f 手，每手保证金 %.2f，每手跌 1 美元等值盈亏额 %.2f，保证金来源=%s",
                referenceLot, cachedMarginPerLot, cachedProfitPerLot,
                (cachedMarginSource == 1 ? "OrderCalcMargin" : "OrderCheck"));
}

//+------------------------------------------------------------------+
//| 极速换算：估算保证金与点差盈亏                                   |
//+------------------------------------------------------------------+
double EstimateMargin(double volume, double targetPrice)
{
    if(!cachedRiskDataValid || volume <= 0 || targetPrice <= 0 ||
       cachedMarginPerLot <= 0 || cachedBasePrice <= 0) return 0;
    return volume * (targetPrice / cachedBasePrice) * cachedMarginPerLot;
}

double EstimateProfit(double volume, double openPrice, double closePrice)
{
    if(!cachedRiskDataValid || volume <= 0 || openPrice <= 0 || closePrice < 0 ||
       cachedProfitPerLot <= 0) return 0;
    return volume * (closePrice - openPrice) * cachedProfitPerLot; 
}

//+------------------------------------------------------------------+
//| 执行初始底仓建仓                                                 |
//+------------------------------------------------------------------+
bool ExecuteInitialBase(double openPrice)
{
    if(InpPureDenseMode)
    {
        Print("🚀 已开启【纯密网模式】，跳过初始底仓建仓阶段。");
        GlobalStartPrice = -1;
        SaveStartPrice();
        return true; 
    }

    if(openPrice >= InpBaseUpperLimit) return false;
    
    int levels = (int)MathFloor((InpBaseUpperLimit - openPrice) / ((double)InpBaseGridPoints * _Point));
    double vol = NormalizeDouble(levels * InpMinLot, 2);
    
    if(vol > 0)
    {
        double margin = 0;
        if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, vol, openPrice, margin)) margin = 0;
        
        if(margin > 0 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin)
        {
            Alert("致命错误：可用保证金不足！无法建立初始底仓，EA将停止。");
            ExpertRemove();
            return false;
        }
        
        trade.SetExpertMagicNumber(InpBaseMagic);
        if(ConfirmTradeResult(trade.Buy(vol, _Symbol, openPrice, 0, InpBaseUpperLimit, "InitBase"), "建立初始底仓", 0))
        {
            GlobalStartPrice = openPrice;
            SaveStartPrice();
            highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - (double)InpOffsetPoints * _Point) / ((double)InpBaseGridPoints * _Point));
            SaveUpperSliceLevel();
            Print("🎉 狙击建仓成功！界河正式确立在: ", GlobalStartPrice);
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| 初始化 (含自动洗盘系统)                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
    {
        Alert("严重错误：账户必须为对冲(Hedging)模式，否则无法运行双核网格！");
        return(INIT_FAILED);
    }

    ConfigureRegions();
    if(!ValidateInputs()) return(INIT_PARAMETERS_INCORRECT);

    InitializeStateNames();
    trade.SetExpertMagicNumber(InpBaseMagic);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    LoadCycleState(bid);
    ReconcileStartState();
    LoadRegionSlices(bid);

    if(exitInProgress || IsEAExitTriggered(bid, InpEAExitPrice))
    {
        exitInProgress = true;
        GlobalVariableSet(gvExitName, 1.0);
        Print("EA 已进入完全结算退出状态：禁止新交易，等待删单、平仓与清零核验。");
        return(INIT_SUCCEEDED);
    }

    // 保留 v3.97 的重载洗盘行为；参数校验已在此前完成，避免错误参数导致误删挂单。
    int deletedOrders = DeleteAllEAPendingOrders();
    if(deletedOrders > 0) PrintFormat("🧹 初始化已清理 %d 个本 EA 历史挂单，准备重新布阵。", deletedOrders);

    UpdateEngineCache(ask);

    if(GlobalStartPrice == 0)
    {
        if(InpPureDenseMode || InpCustomBasePrice <= 0 || ask <= InpCustomBasePrice)
            ExecuteInitialBase(ask);
    }
    UpdateRegionLines();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 主循环引擎 (含 5 秒发包节流阀)                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(exitInProgress || IsEAExitTriggered(bid, InpEAExitPrice))
    {
        ProcessExit();
        return;
    }

    if(GlobalStartPrice == 0 && (InpPureDenseMode || (InpCustomBasePrice > 0 && ask <= InpCustomBasePrice)))
        ExecuteInitialBase(ask);

    UpdateEngineCache(ask);

    sliceActionsThisTick = 0;
    UpdateRegionLines();
    // 先完成上一轮未完成的合并交易，再按每笔合并仓自己的原始止盈阶梯拆分。
    ProcessPendingMergePlans();
    DynamicTPUpdater();
    ProcessMergedBatchSplits();
    ManageCrossUpLogic();
    ManageOrderConsolidation();
    DrawRiskPanel();
    
    // 【v3.90 5秒对表发包引擎】
    static datetime lastGridSyncTime = 0;
    datetime currentTime = TimeCurrent();
    if(currentTime / 5 > lastGridSyncTime / 5)
    {
        ManageGridOrders(); 
        lastGridSyncTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| 切分与断网补偿追偿逻辑                                           |
//+------------------------------------------------------------------+
int SliceOneManagedUnit(int region = -1)
{
    ulong ticket = 0;
    double largestVolume = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong currentTicket = PositionGetTicket(i);
        if(currentTicket == 0 || !PositionSelectByTicket(currentTicket)) continue;
        ulong magic = PositionGetInteger(POSITION_MAGIC);
        if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
           PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY || IsMergedMagic(magic)) continue;
        if(region < 0)
        {
            if(!IsBaseSystemMagic(magic)) continue;
        }
        else if(magic != regions[region].magic || HasPendingMerge(magic) || RememberDenseTarget() <= 0) continue;
        double volume = PositionGetDouble(POSITION_VOLUME);
        if(region < 0 && volume + VolumeTolerance() < InpMinLot) continue;
        if(volume > largestVolume) { largestVolume = volume; ticket = currentTicket; }
    }
    if(ticket == 0) return 0;
    if(!PositionSelectByTicket(ticket)) return -1;
    trade.SetExpertMagicNumber(PositionGetInteger(POSITION_MAGIC));
    // 密网碎单以其实际原手数为一单位，不按新手数裁切旧碎单。
    if(region >= 0 || largestVolume <= InpMinLot + VolumeTolerance())
        return ConfirmTradeResult(trade.PositionClose(ticket), "补切所属体系一单位仓位", ticket) ? 1 : -1;
    return ConfirmTradeResult(trade.PositionClosePartial(ticket, NormalizeDouble(InpMinLot, 2)),
                              "补切底仓一单位仓位", ticket) ? 1 : -1;
}

void SaveSliceProgress(int region, int level)
{
    if(region < 0) { highestSlicedLevelUp = level; SaveUpperSliceLevel(); }
    else { regions[region].sliceLevel = level; SaveRegionSlice(region); }
}

void ProcessMissedSliceLevels(int region, int currentLevel, double step, double offset)
{
    int lastLevel = region < 0 ? highestSlicedLevelUp : regions[region].sliceLevel;
    if(currentLevel <= lastLevel) return;
    for(int level = lastLevel + 1; level <= currentLevel; level++)
    {
        double levelPrice = level * step + offset;
        if((region < 0 && levelPrice <= GlobalStartPrice + _Point) ||
           CheckHistoryForExit(levelPrice, step, region))
        {
            SaveSliceProgress(region, level);
            continue;
        }
        if(sliceActionsThisTick >= MAX_SLICE_ACTIONS_PER_TICK) break;
        int result = SliceOneManagedUnit(region);
        if(result > 0)
        {
            sliceActionsThisTick++;
            SaveSliceProgress(region, level);
            continue;
        }
        if(result == 0) SaveSliceProgress(region, currentLevel);
        break;
    }
}

void ManageCrossUpLogic()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stepUp = InpBaseGridPoints * _Point;
    double off = InpOffsetPoints * _Point;
    if(GlobalStartPrice > 0 && highestSlicedLevelUp == UNINITIALIZED_LEVEL)
    {
        highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - off) / stepUp);
        SaveUpperSliceLevel();
    }
    if(GlobalStartPrice > 0 && bid >= GlobalStartPrice)
        ProcessMissedSliceLevels(-1, (int)MathFloor((bid - off) / stepUp), stepUp, off);
    for(int r = 0; r < 3; r++)
    {
        if(regions[r].points <= 0 || HasPendingMerge(regions[r].magic)) continue;
        double step = regions[r].points * _Point;
        if(regions[r].sliceLevel == UNINITIALIZED_LEVEL)
        {
            regions[r].sliceLevel = (int)MathFloor((bid - off) / step);
            SaveRegionSlice(r);
        }
        if(bid < GetDenseGridTop(r))
            ProcessMissedSliceLevels(r, (int)MathFloor((bid - off) / step), step, off);
    }
    lastBidLower = bid;
}

//+------------------------------------------------------------------+
//| 订单身份：九个 Magic 各自承担唯一职责                            |
//+------------------------------------------------------------------+
bool IsStrategicPosition(ulong magic)
{
    return (magic == InpBaseMagic || IsMergedMagic(magic));
}

int TakeProfitPointsForMagic(ulong magic)
{
    int r = RegionForMagic(magic);
    return r >= 0 ? regions[r].takeProfit : InpBaseTakeProfit;
}

//+------------------------------------------------------------------+
//| 动态维护所有订单的止盈参数 (v3.97 体积绝对霸权认证)              |
//+------------------------------------------------------------------+
void DynamicTPUpdater()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
    
    // --- 1. 修正持仓 TP ---
    for(int i=PositionsTotal()-1; i>=0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_SYMBOL)==_Symbol)
        {
            ulong m = PositionGetInteger(POSITION_MAGIC); 
            double op = PositionGetDouble(POSITION_PRICE_OPEN);
            double tp = PositionGetDouble(POSITION_TP);
            double exp = tp;
            
            if(IsManagedMagic(m))
            {
                trade.SetExpertMagicNumber(m);
                // 所有合并 Magic 都绝不写统一 TP；有状态的新批次由其专属阶梯拆分，
                // 无状态的历史合并仓也保持原状，避免升级时误改其成交管理。
                long positionIdentifier = PositionGetInteger(POSITION_IDENTIFIER);
                if(IsMergedMagic(m))
                {
                    if(HasActiveMergeState(m, positionIdentifier) && MathAbs(tp) > 0.5 * _Point)
                    {
                        ConfirmTradeResult(trade.PositionModify(PositionGetTicket(i), 0, 0),
                                           "清除合并仓统一止盈", PositionGetTicket(i));
                    }
                    continue;
                }

                bool isBase = IsStrategicPosition(m);
                if(IsDenseSourceMagic(m))
                {
                    exp = RememberDenseTarget();
                    if(exp <= 0) continue;
                }
                else exp = isBase ? InpBaseUpperLimit : op + (double)TakeProfitPointsForMagic(m) * _Point;
                    
                // 防御 invalid stops 死循环
                if(!isBase && exp <= bid)
                {
                    Print("🚨 行情已越过网格理论止盈线，触发防倒挂强制收割: ", PositionGetTicket(i));
                    ConfirmTradeResult(trade.PositionClose(PositionGetTicket(i)), "防倒挂强制平仓", PositionGetTicket(i));
                }
                else if(MathAbs(tp - NormalizeDouble(exp, _Digits)) > 0.5*_Point) 
                {
                    ConfirmTradeResult(trade.PositionModify(PositionGetTicket(i), 0, NormalizeDouble(exp, _Digits)),
                                       "更新持仓止盈", PositionGetTicket(i));
                }
            }
        }
    }
    
    // --- 2. 修正挂单 TP ---
    for(int j=OrdersTotal()-1; j>=0; j--)
    {
        if(OrderSelect(OrderGetTicket(j)) && OrderGetString(ORDER_SYMBOL)==_Symbol)
        {
            ulong m = OrderGetInteger(ORDER_MAGIC); 
            double op = OrderGetDouble(ORDER_PRICE_OPEN);
            double tp = OrderGetDouble(ORDER_TP);
            double exp = tp;
            
            if(m==InpBaseGridMagic || IsDenseSourceMagic(m))
            {
                exp = op + (double)TakeProfitPointsForMagic(m) * _Point;
                if(MathAbs(tp - NormalizeDouble(exp, _Digits)) > 0.5*_Point) 
                {
                    ConfirmTradeResult(trade.OrderModify(OrderGetTicket(j), op, 0, NormalizeDouble(exp, _Digits), ORDER_TIME_GTC, 0),
                                       "更新挂单止盈", OrderGetTicket(j));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 风控推演面板 (适配美分账户与 UI 精简)                            |
//+------------------------------------------------------------------+
double CalculateStopOutPrice(double volume, double averageOpen, double balance,
                             int stopOutMode, double stopOutLevel)
{
    if(!cachedRiskDataValid || volume <= 0 || averageOpen <= 0) return EMPTY_VALUE;

    double result = EMPTY_VALUE;
    if(stopOutMode == ACCOUNT_STOPOUT_MODE_PERCENT)
    {
        double marginThresholdPerLot = (cachedMarginPerLot / cachedBasePrice) * (stopOutLevel / 100.0);
        double denominator = volume * (cachedProfitPerLot - marginThresholdPerLot);
        if(MathAbs(denominator) <= 0.0000000001) return EMPTY_VALUE;
        result = (volume * cachedProfitPerLot * averageOpen - balance) / denominator;
    }
    else
    {
        double denominator = volume * cachedProfitPerLot;
        if(MathAbs(denominator) <= 0.0000000001) return EMPTY_VALUE;
        result = averageOpen + (stopOutLevel - balance) / denominator;
    }

    return MathIsValidNumber(result) ? result : EMPTY_VALUE;
}

string RiskPriceText(double price)
{
    return DoubleToString(MathMax(0.0, price), _Digits);
}

// 等差网格用端点和层数求和，端点仍以交易使用的规范化价格严格复核。
bool GridRangeTotals(double bottom, double exclusiveTop, int points, double lot,
                     double offset, double &volume, double &cost)
{
    volume = 0;
    cost = 0;
    if(points <= 0 || lot <= 0 || !MathIsValidNumber(bottom) || !MathIsValidNumber(exclusiveTop))
        return false;
    if(exclusiveTop <= bottom) return true;
    double step = points * _Point;
    double lowIndex = MathCeil((bottom - offset) / step);
    double highIndex = MathCeil((exclusiveTop - offset) / step) - 1;
    if(MathAbs(lowIndex) > 9e15 || MathAbs(highIndex) > 9e15) return false;
    long first = (long)lowIndex, last = (long)highIndex;
    while(NormalizeDouble(first * step + offset, _Digits) < bottom) first++;
    while(NormalizeDouble((first - 1) * step + offset, _Digits) >= bottom) first--;
    while(NormalizeDouble(last * step + offset, _Digits) >= exclusiveTop) last--;
    while(NormalizeDouble((last + 1) * step + offset, _Digits) < exclusiveTop) last++;
    if(first > last) return true;
    double count = (double)(last - first + 1);
    double firstPrice = NormalizeDouble(first * step + offset, _Digits);
    double lastPrice = NormalizeDouble(last * step + offset, _Digits);
    volume = count * lot;
    cost = volume * (firstPrice + lastPrice) * 0.5;
    return MathIsValidNumber(volume) && MathIsValidNumber(cost);
}

bool FullGridTotals(const int &points[], double &volume, double &cost)
{
    volume = 0;
    cost = 0;
    double off = InpOffsetPoints * _Point;
    double v = 0, c = 0;
    double baseAnchor = GetBaseAnchor();
    if(GlobalStartPrice > 0 && baseAnchor > 0)
    {
        if(!GridRangeTotals(baseAnchor, InpBaseUpperLimit, InpBaseGridPoints, InpMinLot, off, v, c))
            return false;
        volume += v; cost += c;
    }
    for(int r = 0; r < 3; r++)
    {
        if(!regions[r].enabled) continue;
        if(!GridRangeTotals(regions[r].bottom, GetDenseGridTop(r) - 0.001, points[r],
                            regions[r].lot, off, v, c)) return false;
        volume += v; cost += c;
    }
    return MathIsValidNumber(volume) && MathIsValidNumber(cost);
}

double LowestEnabledBottom()
{
    double bottom = 0;
    for(int r = 0; r < 3; r++)
        if(regions[r].enabled && (bottom == 0 || regions[r].bottom < bottom))
            bottom = regions[r].bottom;
    return bottom;
}

int densityPoints[3];
int densityLimit[3];
int densityStatus = 0; // 0=计算中，1=找到最密可行组合，2=无可行组合，3=不可用
string densitySignature = "";

// ceil(originalPoints * scale) 的变化点为有理数 k/originalPoints。
// 按变化点顺序遍历所有不同组合，不假设离散风险关于间距单调。
bool AdvanceDensityCandidate()
{
    int next = -1;
    for(int r = 0; r < 3; r++)
    {
        if(!regions[r].enabled || densityPoints[r] >= densityLimit[r]) continue;
        if(next < 0 || (long)densityPoints[r] * regions[next].points <
                       (long)densityPoints[next] * regions[r].points) next = r;
    }
    if(next < 0) return false;
    int numerator = densityPoints[next], denominator = regions[next].points;
    for(int r = 0; r < 3; r++)
    {
        if(!regions[r].enabled) continue;
        long value = (long)regions[r].points * numerator / denominator + 1;
        if(value > 2147483646) { densityStatus = 3; return false; }
        densityPoints[r] = (int)value;
    }
    return true;
}

bool PsychologicalFeasible(double volume, double cost, double balance, int mode, double stopLevel)
{
    double profit = volume > 0 ? EstimateProfit(volume, cost / volume, InpPsyStopOutLevel) : 0;
    double margin = volume > 0 ? EstimateMargin(volume, InpPsyStopOutLevel) : 0;
    double threshold = mode == ACCOUNT_STOPOUT_MODE_PERCENT ? margin * stopLevel / 100.0 : stopLevel;
    return balance + profit > threshold;
}

string DensityResult(double balance, int mode, double stopLevel)
{
    if(LowestEnabledBottom() <= 0) return "⑦ 最密间距：不适用（全部区间关闭）";
    string signature = DoubleToString(balance, 8) + "|" + IntegerToString((long)lastCacheUpdateTime) +
                       "|" + DoubleToString(GetBaseAnchor(), _Digits) + "|" + IntegerToString(mode) +
                       "|" + DoubleToString(stopLevel, 8);
    for(int r = 0; r < 3; r++)
        signature += "|" + DoubleToString(GetDenseGridTop(r), _Digits);
    if(signature != densitySignature)
    {
        densitySignature = signature;
        densityStatus = 0;
        double off = InpOffsetPoints * _Point;
        for(int r = 0; r < 3; r++)
        {
            densityPoints[r] = 1;
            double bound = MathCeil(MathMax(MathAbs(GetDenseGridTop(r) - off),
                                          MathAbs(regions[r].bottom - off)) / _Point) + 2;
            if(regions[r].enabled && (bound > 2147483646 || bound < 1)) densityStatus = 3;
            densityLimit[r] = (int)MathMin(2147483646.0, MathMax(1.0, bound));
        }
    }
    ulong started = GetMicrosecondCount();
    for(int batch = 0; densityStatus == 0 && batch < 2048; batch++)
    {
        double volume = 0, cost = 0;
        if(!FullGridTotals(densityPoints, volume, cost)) { densityStatus = 3; break; }
        if(PsychologicalFeasible(volume, cost, balance, mode, stopLevel)) { densityStatus = 1; break; }
        if(!AdvanceDensityCandidate()) { if(densityStatus == 0) densityStatus = 2; break; }
        if(GetMicrosecondCount() - started >= 3000) break;
    }
    if(densityStatus == 0) return "⑦ 最密间距：计算中";
    if(densityStatus == 2) return "⑦ 最密间距：当前资金无可行组合";
    if(densityStatus == 3) return "⑦ 最密间距：计算不可用";
    string result = "⑦ 最密间距（报价点）：";
    for(int r = 0; r < 3; r++)
    {
        if(r > 0) result += " / ";
        result += StringFormat("%d区 %s", r + 1, regions[r].enabled ? IntegerToString(densityPoints[r]) : "关闭");
    }
    return result;
}

void DrawRiskPanel()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double bottom = LowestEnabledBottom();

    int stopOutMode = (int)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
    double stopOutLevel = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);

    int baseCount = 0;
    int gridCount = 0;
    int gridMergedCount = 0;
    double baseVolume = 0;
    double gridVolume = 0;
    double gridMergedVolume = 0;
    double currentVolume = 0;
    double currentCost = 0;
    int symbolPositionCount = 0;
    string positionDetails = "";

    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket) ||
           PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        symbolPositionCount++;
        ulong magic = PositionGetInteger(POSITION_MAGIC);
        double volume = PositionGetDouble(POSITION_VOLUME);
        string category = "未受管";
        if(magic == InpBaseMagic || magic == InpBaseGridMagic || magic == InpBaseMergedMagic)
            category = "底仓";
        else if(IsDenseSourceMagic(magic))
            category = "网格";
        else if(IsDenseMergedMagic(magic))
            category = "网格合并";

        if(positionDetails != "") positionDetails += "; ";
        positionDetails += StringFormat("ticket=%I64u/magic=%I64u/volume=%.8f/category=%s",
                                        ticket, magic, volume, category);
        if(!IsManagedMagic(magic)) continue;

        currentVolume += volume;
        currentCost += volume * PositionGetDouble(POSITION_PRICE_OPEN);

        if(magic == InpBaseMagic || magic == InpBaseGridMagic || magic == InpBaseMergedMagic)
        {
            baseCount++;
            baseVolume += volume;
        }
        else if(IsDenseSourceMagic(magic))
        {
            gridCount++;
            gridVolume += volume;
        }
        else if(IsDenseMergedMagic(magic))
        {
            gridMergedCount++;
            gridMergedVolume += volume;
        }
    }

    int totalCount = baseCount + gridCount + gridMergedCount;
    double totalVolume = baseVolume + gridVolume + gridMergedVolume;
    if(!positionAuditLogged)
    {
        if(positionDetails == "") positionDetails = "(none)";
        PrintFormat("监控持仓对账：symbol=%s，symbolPositions=%d，managed=%d，底仓=%d/%.8f，网格=%d/%.8f，网格合并=%d/%.8f，总计=%d/%.8f，明细=[%s]",
                    _Symbol, symbolPositionCount, totalCount,
                    baseCount, baseVolume, gridCount, gridVolume,
                    gridMergedCount, gridMergedVolume, totalCount, totalVolume,
                    positionDetails);
        positionAuditLogged = true;
    }

    double currentAverageOpen = (currentVolume > 0) ? currentCost / currentVolume : 0;

    int points[3];
    for(int r = 0; r < 3; r++) points[r] = regions[r].points;
    double fullVolume = 0, fullCost = 0;
    bool fullValid = FullGridTotals(points, fullVolume, fullCost);
    double fullAverageOpen = (fullVolume > 0) ? fullCost / fullVolume : 0;

    bool riskAvailable = fullValid && cachedRiskDataValid && cachedReferenceLot > 0 &&
                         cachedMarginPerLot >= 0 && cachedProfitPerLot > 0 && cachedBasePrice > 0;
    double currentMargin = 0;
    double currentMarginLevel = 0;
    double currentBottomMargin = 0;
    double currentBottomEquity = 0;
    double currentBottomLevel = 0;
    double fullBottomMargin = 0;
    double fullBottomEquity = 0;
    double fullBottomLevel = 0;
    double currentStopOut = EMPTY_VALUE;
    double fullStopOut = EMPTY_VALUE;
    double requiredFunds = 0;
    string densityText = "";

    if(riskAvailable)
    {
        if(currentVolume > 0)
        {
            currentMargin = EstimateMargin(currentVolume, ask);
            currentMarginLevel = (currentMargin > 0) ? equity / currentMargin * 100.0 : EMPTY_VALUE;
            if(bottom > 0)
            {
                currentBottomMargin = EstimateMargin(currentVolume, bottom);
                currentBottomEquity = balance + EstimateProfit(currentVolume, currentAverageOpen, bottom);
                currentBottomLevel = currentBottomMargin > 0 ? currentBottomEquity / currentBottomMargin * 100.0 : EMPTY_VALUE;
            }
            currentStopOut = CalculateStopOutPrice(currentVolume, currentAverageOpen, balance,
                                                   stopOutMode, stopOutLevel);
        }

        if(fullVolume > 0)
        {
            if(bottom > 0)
            {
                fullBottomMargin = EstimateMargin(fullVolume, bottom);
                fullBottomEquity = balance + EstimateProfit(fullVolume, fullAverageOpen, bottom);
                fullBottomLevel = fullBottomMargin > 0 ? fullBottomEquity / fullBottomMargin * 100.0 : EMPTY_VALUE;
            }
            fullStopOut = CalculateStopOutPrice(fullVolume, fullAverageOpen, balance,
                                                stopOutMode, stopOutLevel);

            if(InpPsyStopOutLevel > 0)
            {
                double equityAtPsychological = balance + EstimateProfit(fullVolume, fullAverageOpen,
                                                                         InpPsyStopOutLevel);
                double marginAtPsychological = EstimateMargin(fullVolume, InpPsyStopOutLevel);
                double thresholdAtPsychological = (stopOutMode == ACCOUNT_STOPOUT_MODE_PERCENT) ?
                                                  marginAtPsychological * (stopOutLevel / 100.0) : stopOutLevel;
                if(equityAtPsychological < thresholdAtPsychological)
                    requiredFunds = thresholdAtPsychological - equityAtPsychological;
            }


        }
    }

    if(riskAvailable) densityText = DensityResult(balance, stopOutMode, stopOutLevel);

    double displayRate = 1.0;
    string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
    StringToUpper(accountCurrency);
    if(StringFind(accountCurrency, "USC") >= 0 || StringFind(accountCurrency, "CENT") >= 0)
        displayRate = 100.0;

    string lines[11];
    lines[0] = "【风控数据】" + ((GlobalStartPrice == -1) ? " [纯密网模式]" : "");

    bool highRisk = false;
    bool marginWarning = false;
    if(!riskAvailable)
    {
        string unavailable = StringFormat("监控数据不可用（风控基准计算失败，错误码：%d）", cachedRiskErrorCode);
        lines[1] = "① " + unavailable;
        lines[2] = "② " + unavailable;
        lines[3] = "③ " + unavailable;
        lines[4] = "④ " + unavailable;
        lines[5] = "⑤ " + unavailable;
        lines[6] = "⑥ " + unavailable;
        lines[7] = "⑦ " + unavailable;
        lines[10] = "监控数据不可用：安全状态未判定";
    }
    else
    {
        if(currentVolume > 0)
        {
            string currentMarginLevelText = (cachedMarginFreeMode && currentMargin <= 0) ?
                                             "免保证金" : StringFormat("%.2f%%", currentMarginLevel);
            string currentBottomLevelText = (cachedMarginFreeMode && currentBottomMargin <= 0) ?
                                            "免保证金" : StringFormat("%.2f%%", currentBottomLevel);
            lines[1] = StringFormat("① 当前EA占用保证金：$%.2f，比例：%s",
                                    currentMargin / displayRate, currentMarginLevelText);
            lines[2] = StringFormat("② 当前持仓跌至网格底部(%s)时，占用：$%.2f，比例：%s",
                                    RiskPriceText(bottom), currentBottomMargin / displayRate, currentBottomLevelText);
            lines[4] = (currentStopOut == EMPTY_VALUE) ? "④ 当前持仓爆仓线：无法计算" :
                       StringFormat("④ 当前持仓爆仓线：%s%s", RiskPriceText(currentStopOut),
                                    (currentStopOut < 0 ? " (黄金归零亦不爆仓)" : ""));
        }
        else
        {
            lines[1] = "① 当前EA占用保证金：$0.00（当前无持仓）";
            lines[2] = "② 当前持仓跌至网格底部：当前无持仓";
            lines[4] = "④ 当前持仓爆仓线：当前无持仓";
        }

        if(fullVolume > 0)
        {
            string fullBottomLevelText = (cachedMarginFreeMode && fullBottomMargin <= 0) ?
                                         "免保证金" : StringFormat("%.2f%%", fullBottomLevel);
            lines[3] = StringFormat("③ 配置满载并触底时占用保证金：$%.2f，比例：%s",
                                    fullBottomMargin / displayRate, fullBottomLevelText);
            lines[5] = (fullStopOut == EMPTY_VALUE) ? "⑤ 配置满载时爆仓线：无法计算" :
                       StringFormat("⑤ 配置满载时爆仓线：%s%s", RiskPriceText(fullStopOut),
                                    (fullStopOut < 0 ? " (黄金归零亦不爆仓)" : ""));
            lines[6] = (requiredFunds <= 0) ?
                       StringFormat("⑥ 配置满载防线 (%s) 需补充保证金：$0.00 (安全通过)",
                                    RiskPriceText(InpPsyStopOutLevel)) :
                       StringFormat("⑥ 配置满载防线 (%s) 需补充保证金：$%.2f",
                                    RiskPriceText(InpPsyStopOutLevel), requiredFunds / displayRate);
            lines[7] = densityText;
        }
        else
        {
            lines[3] = "③ 配置满载并触底：当前参数下没有可推演仓位";
            lines[5] = "⑤ 配置满载时爆仓线：无法计算";
            lines[6] = "⑥ 配置满载防线：无法计算";
            lines[7] = "⑦ 当前仓位可铺设最密网格：无法计算";
        }

        if(bottom > 0 && currentStopOut != EMPTY_VALUE && currentStopOut >= bottom) highRisk = true;
        if(bottom > 0 && fullStopOut != EMPTY_VALUE && fullStopOut >= bottom) highRisk = true;
        if(bottom > 0 && !cachedMarginFreeMode && currentVolume > 0 && currentBottomLevel < 100.0) marginWarning = true;
        if(bottom > 0 && !cachedMarginFreeMode && fullVolume > 0 && fullBottomLevel < 100.0) marginWarning = true;

        if(highRisk) lines[10] = "高危：极端行情下，防线之上将达到强平条件";
        else if(marginWarning) lines[10] = "警告：跌至底部时将面临追保 (Margin Call)";
        else lines[10] = "安全：按当前推演，物理防线内保证金充足";
        lines[7] = densityText;
        if(bottom <= 0)
        {
            lines[2] = "② 跌至区间底部：不适用（全部区间关闭）";
            lines[3] = "③ 配置满载触底：不适用（全部区间关闭）";
            lines[10] = "全部区间关闭：已有持仓仍按实际仓位管理";
        }
    }

    lines[8] = StringFormat("⑧ 底仓单量：%d，网格单量：%d，网格合并单量：%d，总量：%d",
                            baseCount, gridCount, gridMergedCount, totalCount);
    lines[9] = StringFormat("⑨ 底仓手数：%.2f，网格手数：%.2f，网格合并手数：%.2f，总手数：%.2f",
                            baseVolume, gridVolume, gridMergedVolume, totalVolume);

    int spacing = InpPanelFontSize + 12;
    for(int i = 0; i < 11; i++)
    {
        string name = "RPL_" + IntegerToString(i);
        if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + i * spacing);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpPanelFontSize);
        ObjectSetString(0, name, OBJPROP_FONT, "微软雅黑");
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);

        color lineColor = clrWhite;
        if(i == 0) lineColor = clrGold;
        else if(i == 1) lineColor = clrLightSkyBlue;
        else if(i == 6 && riskAvailable && requiredFunds > 0) lineColor = clrMagenta;
        else if(i == 10)
        {
            if(!riskAvailable || highRisk) lineColor = clrRed;
            else if(marginWarning) lineColor = clrGold;
            else lineColor = clrLimeGreen;
        }
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
    }
}

//+------------------------------------------------------------------+
//| 退出状态机：冻结新交易 → 删挂单 → 平持仓 → 核验 → 卸载          |
//+------------------------------------------------------------------+
int DeleteAllEAPendingOrders()
{
    int deleted = 0;
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong ticket = OrderGetTicket(j);
        if(ticket == 0 || !OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol || !IsManagedMagic(OrderGetInteger(ORDER_MAGIC))) continue;

        if(ConfirmTradeResult(trade.OrderDelete(ticket), "删除挂单", ticket)) deleted++;
    }
    return deleted;
}

int CloseAllEAPositions()
{
    int closed = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol || !IsManagedMagic(PositionGetInteger(POSITION_MAGIC))) continue;

        trade.SetExpertMagicNumber(PositionGetInteger(POSITION_MAGIC));
        if(ConfirmTradeResult(trade.PositionClose(ticket), "平持仓", ticket)) closed++;
    }
    return closed;
}

bool HasManagedExposure()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong positionTicket = PositionGetTicket(i);
        if(positionTicket > 0 && PositionSelectByTicket(positionTicket) &&
           PositionGetString(POSITION_SYMBOL) == _Symbol &&
           IsManagedMagic(PositionGetInteger(POSITION_MAGIC))) return true;
    }
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong orderTicket = OrderGetTicket(j);
        if(orderTicket > 0 && OrderSelect(orderTicket) &&
           OrderGetString(ORDER_SYMBOL) == _Symbol &&
           IsManagedMagic(OrderGetInteger(ORDER_MAGIC))) return true;
    }
    return false;
}

void ProcessExit()
{
    if(!exitInProgress)
    {
        exitInProgress = true;
        GlobalVariableSet(gvExitName, 1.0);
        Print("已触达EA完全结算退出价，进入退出中状态并冻结全部新交易。");
    }

    int deleted = DeleteAllEAPendingOrders();
    int closed = CloseAllEAPositions();

    if(!HasManagedExposure())
    {
        ClearCycleState();
        Alert("EA完全结算退出已确认：本 EA 的持仓和挂单均已清零，现自动卸载 EA。");
        ExpertRemove();
        return;
    }

    PrintFormat("退出中：本轮已删除 %d 个挂单、已提交 %d 笔平仓；仍有本 EA 曝险，将在后续 tick 重试。", deleted, closed);
}

//+------------------------------------------------------------------+
//| 查阅历史服务器账单 (扩大至 30 天防遗忘)                          |
//+------------------------------------------------------------------+
bool CheckHistoryForExit(double price, double interval, int region)
{
    if(!HistorySelect(TimeCurrent()-86400*30, TimeCurrent())) return false;
    for(int i = HistoryDealsTotal()-1; i >= 0; i--)
    {
        ulong deal = HistoryDealGetTicket(i);
        ulong magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
        bool owned = region < 0 ? IsBaseSystemMagic(magic) :
                     (magic == regions[region].magic || magic == regions[region].mergedMagic);
        if(owned && HistoryDealGetString(deal, DEAL_SYMBOL) == _Symbol &&
           HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_OUT &&
           MathAbs(HistoryDealGetDouble(deal, DEAL_PRICE) - price) < interval * 0.5) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| 网格挂单生成器与动态吸尘器 (v3.95 核心升级：死区防抖与滞后缓冲带)|
//+------------------------------------------------------------------+
void ManageGridOrders()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stepUp = InpBaseGridPoints * _Point;
    double off = InpOffsetPoints * _Point;
    double maxT = 0, baseAnchor = 0;
    if(GlobalStartPrice > 0)
    {
        maxT = (highestSlicedLevelUp - 1) * stepUp + off;
        baseAnchor = GetBaseAnchor();
    }
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong ticket = OrderGetTicket(j);
        if(ticket == 0 || !OrderSelect(ticket) || OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        ulong magic = OrderGetInteger(ORDER_MAGIC);
        double price = OrderGetDouble(ORDER_PRICE_OPEN);
        bool remove = false;
        if(magic == InpBaseGridMagic)
            remove = GlobalStartPrice <= 0 || price < baseAnchor - 0.001 || price > maxT + 0.001;
        else if(IsDenseSourceMagic(magic))
        {
            int r = RegionForMagic(magic);
            remove = !regions[r].enabled;
            if(!remove)
            {
                double step = regions[r].points * _Point;
                double current = MathFloor(ask / step) * step;
                double bound = current - (regions[r].levels - 1) * step + off - 2 * step;
                remove = price < bound - 0.001 || !DensePriceAllowed(r, price);
            }
        }
        if(remove) ConfirmTradeResult(trade.OrderDelete(ticket), "清理所属体系越界或停用挂单", ticket);
    }
    if(GlobalStartPrice > 0 && !HasPendingMerge(InpBaseGridMagic))
    {
        double current = MathFloor(ask / stepUp) * stepUp;
        trade.SetExpertMagicNumber(InpBaseGridMagic);
        for(int i = 0; i < 100; i++)
        {
            double price = NormalizeDouble(current - i * stepUp + off, _Digits);
            if(price < baseAnchor - 0.001) break;
            if(price > maxT || ask - price < stepUp) continue;
            if(!CheckLevelExists(price, InpBaseGridMagic, stepUp))
                ConfirmTradeResult(trade.BuyLimit(InpMinLot, price, _Symbol, 0,
                                   price + InpBaseTakeProfit * _Point, ORDER_TIME_GTC, 0, "GridBuy"),
                                   "铺设底仓回补挂单", 0);
        }
    }
    for(int r = 0; r < 3; r++)
    {
        if(!regions[r].enabled || HasPendingMerge(regions[r].magic)) continue;
        double step = regions[r].points * _Point;
        trade.SetExpertMagicNumber(regions[r].magic);
        for(int j = 0; j < regions[r].levels; j++)
        {
            double price = DenseCandidatePrice(r, ask, j);
            if(!DenseCandidateAllowed(r, ask, price)) continue;
            if(!CheckLevelExists(price, regions[r].magic, step))
                ConfirmTradeResult(trade.BuyLimit(regions[r].lot, price, _Symbol, 0,
                                   price + regions[r].takeProfit * _Point, ORDER_TIME_GTC, 0,
                                   StringFormat("GridR%d", r + 1)), "铺设独立区间挂单", 0);
        }
    }
}

//+------------------------------------------------------------------+
//| 合并批次：严格数量、专属状态与原止盈阶梯                         |
//+------------------------------------------------------------------+
string MergePlanPrefix(ulong sourceMagic)
{
    return mergeStateScope + "_P" + StringFormat("%I64u", sourceMagic) + "_";
}

string MergeActivePrefix(ulong mergedMagic, long positionIdentifier)
{
    return mergeStateScope + "_A" + StringFormat("%I64u", mergedMagic) +
           "_" + StringFormat("%I64d", positionIdentifier) + "_";
}

string MergePlanKey(ulong sourceMagic, string suffix)
{
    return MergePlanPrefix(sourceMagic) + suffix;
}

string MergePlanFragmentKey(ulong sourceMagic, int index, string suffix)
{
    return MergePlanPrefix(sourceMagic) + "F" + IntegerToString(index) + suffix;
}

string MergeActiveKey(ulong mergedMagic, long positionIdentifier, string suffix)
{
    return MergeActivePrefix(mergedMagic, positionIdentifier) + suffix;
}

string MergeActiveUnitKey(ulong mergedMagic, long positionIdentifier, int index, string suffix)
{
    return MergeActivePrefix(mergedMagic, positionIdentifier) + "U" + IntegerToString(index) + suffix;
}

double ReadMergeState(string name, double fallback)
{
    return GlobalVariableCheck(name) ? GlobalVariableGet(name) : fallback;
}

void ClearMergePlan(ulong sourceMagic)
{
    GlobalVariablesDeleteAll(MergePlanPrefix(sourceMagic));
}

void ClearActiveMergeState(ulong mergedMagic, long positionIdentifier)
{
    GlobalVariablesDeleteAll(MergeActivePrefix(mergedMagic, positionIdentifier));
}

void ClearAllMergeStateScope()
{
    if(StringLen(mergeStateScope) > 0)
        GlobalVariablesDeleteAll(mergeStateScope);
}

bool HasPendingMerge(ulong sourceMagic)
{
    int state = (int)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "S"), 0));
    return (state == MERGE_PENDING_CLOSING || state == MERGE_PENDING_OPENING ||
            state == MERGE_PENDING_OPENED_UNBOUND);
}

bool HasActiveMergeState(ulong mergedMagic, long positionIdentifier)
{
    return ReadMergeState(MergeActiveKey(mergedMagic, positionIdentifier, "C"), 0) > 0.5;
}

bool IsMergeableSourcePosition(ulong sourceMagic)
{
    if(sourceMagic != InpBaseGridMagic && !IsDenseSourceMagic(sourceMagic)) return false;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
       PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY ||
       PositionGetInteger(POSITION_MAGIC) != sourceMagic) return false;

    // 碎单身份只由专属 Magic 决定；参数改动前后的 0.01/0.02 等实际手数都可进入同一批。
    return IsBrokerVolumeValid(PositionGetDouble(POSITION_VOLUME)) &&
           (!IsDenseSourceMagic(sourceMagic) || RememberDenseTarget() > 0);
}

double FragmentOriginalTarget(ulong sourceMagic)
{
    if(IsDenseSourceMagic(sourceMagic)) return RememberDenseTarget();
    double target = PositionGetDouble(POSITION_TP);
    if(target > 0) return NormalizeDouble(target, _Digits);

    return NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) +
                           (double)TakeProfitPointsForMagic(sourceMagic) * _Point, _Digits);
}

int CollectOldestMergeFragments(ulong sourceMagic, MergeFragment &fragments[])
{
    ArrayResize(fragments, 0);

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket) || !IsMergeableSourcePosition(sourceMagic)) continue;

        int size = ArraySize(fragments);
        ArrayResize(fragments, size + 1);
        fragments[size].positionIdentifier = PositionGetInteger(POSITION_IDENTIFIER);
        fragments[size].openedAt           = PositionGetInteger(POSITION_TIME_MSC);
        fragments[size].volume             = PositionGetDouble(POSITION_VOLUME);
        fragments[size].targetPrice        = FragmentOriginalTarget(sourceMagic);
    }

    // 数量溢出时严格选最早成交的一整批，后续碎单自然留给下一批。
    for(int i = 1; i < ArraySize(fragments); i++)
    {
        MergeFragment current = fragments[i];
        int j = i - 1;
        while(j >= 0 && (fragments[j].openedAt > current.openedAt ||
              (fragments[j].openedAt == current.openedAt &&
               fragments[j].positionIdentifier > current.positionIdentifier)))
        {
            fragments[j + 1] = fragments[j];
            j--;
        }
        fragments[j + 1] = current;
    }

    if(ArraySize(fragments) > InpMergeThreshold)
        ArrayResize(fragments, InpMergeThreshold);
    return ArraySize(fragments);
}

int CountMergeableSmallPositions(ulong sourceMagic)
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket) && IsMergeableSourcePosition(sourceMagic)) count++;
    }
    return count;
}

int CountManagedItems()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket) &&
           PositionGetString(POSITION_SYMBOL) == _Symbol &&
           IsManagedMagic(PositionGetInteger(POSITION_MAGIC))) count++;
    }
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong ticket = OrderGetTicket(j);
        if(ticket > 0 && OrderSelect(ticket) &&
           OrderGetString(ORDER_SYMBOL) == _Symbol &&
           IsManagedMagic(OrderGetInteger(ORDER_MAGIC))) count++;
    }
    return count;
}

bool StartMergePlan(ulong sourceMagic, ulong mergedMagic)
{
    if(HasPendingMerge(sourceMagic)) return false;

    MergeFragment fragments[];
    int selected = CollectOldestMergeFragments(sourceMagic, fragments);
    if(selected != InpMergeThreshold) return false;

    double combinedVolume = 0;
    for(int i = 0; i < selected; i++) combinedVolume += fragments[i].volume;
    combinedVolume = NormalizeDouble(combinedVolume, 8);
    if(!IsBrokerVolumeValid(combinedVolume))
    {
        PrintFormat("合并计划未启动：%d 笔碎单合计 %.8f 手，不符合当前品种的最小/最大手数或步长。",
                    selected, combinedVolume);
        return false;
    }

    ClearMergePlan(sourceMagic);
    GlobalVariableSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_CLOSING);
    GlobalVariableSet(MergePlanKey(sourceMagic, "M"), (double)mergedMagic);
    GlobalVariableSet(MergePlanKey(sourceMagic, "C"), selected);

    for(int i = 0; i < selected; i++)
    {
        GlobalVariableSet(MergePlanFragmentKey(sourceMagic, i, "I"), (double)fragments[i].positionIdentifier);
        GlobalVariableSet(MergePlanFragmentKey(sourceMagic, i, "V"), fragments[i].volume);
        GlobalVariableSet(MergePlanFragmentKey(sourceMagic, i, "T"), fragments[i].targetPrice);
        GlobalVariableSet(MergePlanFragmentKey(sourceMagic, i, "X"), MERGE_FRAGMENT_PENDING);
    }

    PrintFormat("已锁定 %d 笔原始碎单，开始建立 Magic=%I64u 的独立合并批次。", selected, mergedMagic);
    return true;
}

ulong FindOpenPositionTicketByIdentifier(long positionIdentifier, ulong expectedMagic)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == expectedMagic &&
           PositionGetInteger(POSITION_IDENTIFIER) == positionIdentifier)
            return ticket;
    }
    return 0;
}

// 锁定批次逐笔平仓时，服务器可能先于 EA 请求触发原始 TP。
// 只有确认该碎单完整地以 TP 退出，才允许将其从本批合并中剔除；
// 历史尚未刷新时保持等待，其他退出原因仍取消计划，避免放大仓位。
int ClassifyMissingFragmentExit(long positionIdentifier, double plannedVolume)
{
    if(!HistorySelectByPosition(positionIdentifier)) return MERGE_FRAGMENT_PENDING;

    bool hasExitDeal = false;
    bool allExitDealsAtTP = true;
    double exitedVolume = 0;

    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(dealTicket == 0) continue;

        long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;

        double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
        if(dealVolume <= VolumeTolerance()) continue;

        hasExitDeal = true;
        exitedVolume += dealVolume;
        if(HistoryDealGetInteger(dealTicket, DEAL_REASON) != DEAL_REASON_TP)
            allExitDealsAtTP = false;
    }

    if(!hasExitDeal || exitedVolume + VolumeTolerance() < plannedVolume)
        return MERGE_FRAGMENT_PENDING;

    return allExitDealsAtTP ? MERGE_FRAGMENT_CLOSED_AT_TP : MERGE_FRAGMENT_EXIT_UNKNOWN;
}

bool ConfirmPlannedFragmentClosures(ulong sourceMagic)
{
    int count = (int)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "C"), 0));
    if(count <= 0)
    {
        Print("合并计划数量异常，已取消该计划，不建立新合并仓。");
        ClearMergePlan(sourceMagic);
        return false;
    }

    for(int i = 0; i < count; i++)
    {
        int closeState = (int)MathRound(ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "X"),
                                                        MERGE_FRAGMENT_PENDING));
        if(closeState == MERGE_FRAGMENT_CLOSED_BY_EA || closeState == MERGE_FRAGMENT_CLOSED_AT_TP)
            continue;

        long positionIdentifier = (long)MathRound(ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "I"), 0));
        double plannedVolume = ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "V"), 0);
        ulong ticket = FindOpenPositionTicketByIdentifier(positionIdentifier, sourceMagic);
        if(ticket == 0)
        {
            int exitType = ClassifyMissingFragmentExit(positionIdentifier, plannedVolume);
            if(exitType == MERGE_FRAGMENT_CLOSED_AT_TP)
            {
                GlobalVariableSet(MergePlanFragmentKey(sourceMagic, i, "X"), MERGE_FRAGMENT_CLOSED_AT_TP);
                PrintFormat("合并计划中的碎单 ID=%I64d 已由原始 TP 正常退出；该 %.2f 手不纳入本批合并。",
                            positionIdentifier, plannedVolume);
                continue;
            }

            if(exitType == MERGE_FRAGMENT_EXIT_UNKNOWN)
            {
                // 非 TP 的外部/未知退出，不能冒险补开一笔会放大仓位的合并单。
                PrintFormat("合并计划中的碎单 ID=%I64d 已不在场且成交历史不是原始 TP；计划取消，不建立合并仓。",
                            positionIdentifier);
                ClearMergePlan(sourceMagic);
            }
            // 历史成交尚未同步时，保持计划等待下一次 tick，不能据此取消或开仓。
            return false;
        }

        trade.SetExpertMagicNumber(sourceMagic);
        if(!ConfirmTradeResult(trade.PositionClose(ticket), "关闭已锁定的待合并碎单", ticket)) return false;

        GlobalVariableSet(MergePlanFragmentKey(sourceMagic, i, "X"), MERGE_FRAGMENT_CLOSED_BY_EA);
    }

    GlobalVariableSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_OPENING);
    return true;
}

double PlannedMergeVolume(ulong sourceMagic)
{
    int count = (int)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "C"), 0));
    double volume = 0;
    for(int i = 0; i < count; i++)
    {
        int closeState = (int)MathRound(ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "X"),
                                                        MERGE_FRAGMENT_PENDING));
        if(closeState == MERGE_FRAGMENT_CLOSED_BY_EA)
            volume += ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "V"), 0);
    }
    return NormalizeDouble(volume, 8);
}

long FindNewMergedPositionIdentifier(ulong mergedMagic, double expectedVolume, long requestTimeMsc)
{
    long selectedIdentifier = 0;
    long selectedTime = -1;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
           PositionGetInteger(POSITION_MAGIC) != mergedMagic ||
           PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
        if(MathAbs(PositionGetDouble(POSITION_VOLUME) - expectedVolume) > VolumeTolerance()) continue;

        long positionIdentifier = PositionGetInteger(POSITION_IDENTIFIER);
        long openedAt = PositionGetInteger(POSITION_TIME_MSC);
        if(openedAt + 10000 < requestTimeMsc || HasActiveMergeState(mergedMagic, positionIdentifier)) continue;
        if(openedAt > selectedTime)
        {
            selectedTime = openedAt;
            selectedIdentifier = positionIdentifier;
        }
    }
    return selectedIdentifier;
}

void BindPlanToMergedPosition(ulong sourceMagic, ulong mergedMagic, long positionIdentifier)
{
    int plannedCount = (int)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "C"), 0));
    MergeFragment units[];
    ArrayResize(units, 0);

    for(int i = 0; i < plannedCount; i++)
    {
        int closeState = (int)MathRound(ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "X"),
                                                        MERGE_FRAGMENT_PENDING));
        if(closeState != MERGE_FRAGMENT_CLOSED_BY_EA) continue;

        int unitIndex = ArraySize(units);
        ArrayResize(units, unitIndex + 1);
        units[unitIndex].positionIdentifier = (long)MathRound(ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "I"), 0));
        units[unitIndex].volume             = ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "V"), 0);
        units[unitIndex].targetPrice        = ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "T"), 0);
        units[unitIndex].openedAt           = i;
    }

    int count = ArraySize(units);
    if(count <= 0)
    {
        ClearMergePlan(sourceMagic);
        return;
    }

    // 拆分顺序只服从原始止盈价，和合并单的实际成交价、Comment 或其他批次无关。
    for(int i = 1; i < count; i++)
    {
        MergeFragment current = units[i];
        int j = i - 1;
        while(j >= 0 && (units[j].targetPrice > current.targetPrice ||
              (MathAbs(units[j].targetPrice - current.targetPrice) <= 0.1 * _Point &&
               units[j].positionIdentifier > current.positionIdentifier)))
        {
            units[j + 1] = units[j];
            j--;
        }
        units[j + 1] = current;
    }

    ClearActiveMergeState(mergedMagic, positionIdentifier);
    GlobalVariableSet(MergeActiveKey(mergedMagic, positionIdentifier, "C"), count);
    GlobalVariableSet(MergeActiveKey(mergedMagic, positionIdentifier, "N"), 0.0);
    GlobalVariableSet(MergeActiveKey(mergedMagic, positionIdentifier, "S"), (double)sourceMagic);
    for(int i = 0; i < count; i++)
    {
        GlobalVariableSet(MergeActiveUnitKey(mergedMagic, positionIdentifier, i, "T"), units[i].targetPrice);
        GlobalVariableSet(MergeActiveUnitKey(mergedMagic, positionIdentifier, i, "V"), units[i].volume);
    }

    ClearMergePlan(sourceMagic);
    PrintFormat("合并仓 ID=%I64d 已绑定 %d 个原始止盈阶梯，将从 %.3f 起逐单位拆分。",
                positionIdentifier, count, units[0].targetPrice);
}

bool TryBindOpenedMergePlan(ulong sourceMagic)
{
    ulong mergedMagic = (ulong)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "M"), 0));
    double expectedVolume = PlannedMergeVolume(sourceMagic);
    long requestTimeMsc = (long)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "R"), 0));
    if(mergedMagic == 0 || !IsBrokerVolumeValid(expectedVolume) || requestTimeMsc <= 0) return false;

    long positionIdentifier = FindNewMergedPositionIdentifier(mergedMagic, expectedVolume, requestTimeMsc);
    if(positionIdentifier == 0) return false;

    BindPlanToMergedPosition(sourceMagic, mergedMagic, positionIdentifier);
    return true;
}

bool OpenPlannedMerge(ulong sourceMagic)
{
    ulong mergedMagic = (ulong)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "M"), 0));
    double volume = PlannedMergeVolume(sourceMagic);
    if(mergedMagic == 0)
    {
        Print("合并计划缺少合并 Magic，已取消该计划。");
        ClearMergePlan(sourceMagic);
        return false;
    }
    if(volume <= VolumeTolerance())
    {
        Print("已锁定批次中的碎单均由原始 TP 正常退出，不建立合并仓。");
        ClearMergePlan(sourceMagic);
        return false;
    }
    if(!IsBrokerVolumeValid(volume))
    {
        PrintFormat("合并计划等待：剩余待建仓手数 %.8f 不符合当前品种交易规格。", volume);
        return false;
    }

    long requestTimeMsc = (long)TimeCurrent() * 1000;
    // 先落下“已发送、等待绑定”状态，避免请求成功后恰逢重启而重复开合并仓。
    GlobalVariableSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_OPENED_UNBOUND);
    GlobalVariableSet(MergePlanKey(sourceMagic, "R"), (double)requestTimeMsc);

    trade.SetExpertMagicNumber(mergedMagic);
    string comment = (sourceMagic == InpBaseGridMagic) ? "BaseMerged" : "DownMerged";
    if(!ConfirmTradeResult(trade.Buy(volume, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0, 0, comment),
                           "建立无统一止盈的合并仓", 0))
    {
        GlobalVariableSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_OPENING);
        return false;
    }

    if(!TryBindOpenedMergePlan(sourceMagic))
        Print("合并仓成交已确认，正在等待持仓列表刷新后绑定原始止盈阶梯。");
    return true;
}

void ProcessPendingMergePlan(ulong sourceMagic)
{
    int state = (int)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "S"), 0));
    if(state == MERGE_PENDING_CLOSING)
    {
        if(!ConfirmPlannedFragmentClosures(sourceMagic)) return;
        state = (int)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "S"), 0));
    }

    if(state == MERGE_PENDING_OPENING)
    {
        OpenPlannedMerge(sourceMagic);
        return;
    }

    if(state == MERGE_PENDING_OPENED_UNBOUND)
    {
        if(TryBindOpenedMergePlan(sourceMagic)) return;

        long requestTimeMsc = (long)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "R"), 0));
        if(requestTimeMsc > 0 && (long)TimeCurrent() * 1000 - requestTimeMsc >= 15000)
        {
            Print("等待绑定合并仓超时且未找到成交持仓；将重新发送一次建仓请求。");
            GlobalVariableSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_OPENING);
        }
    }
}

void ProcessPendingMergePlans()
{
    ProcessPendingMergePlan(InpBaseGridMagic);
    for(int r = 0; r < 3; r++) ProcessPendingMergePlan(regions[r].magic);
}

void ProcessOneMergedBatchSplit(ulong ticket, ulong mergedMagic, long positionIdentifier, double bid)
{
    int count = (int)MathRound(ReadMergeState(MergeActiveKey(mergedMagic, positionIdentifier, "C"), 0));
    int next = (int)MathRound(ReadMergeState(MergeActiveKey(mergedMagic, positionIdentifier, "N"), 0));

    for(int actions = 0; actions < MAX_SLICE_ACTIONS_PER_TICK && next < count; actions++)
    {
        double target = ReadMergeState(MergeActiveUnitKey(mergedMagic, positionIdentifier, next, "T"), 0);
        double unitVolume = ReadMergeState(MergeActiveUnitKey(mergedMagic, positionIdentifier, next, "V"), 0);
        if(target <= 0 || !IsBrokerVolumeValid(unitVolume))
        {
            PrintFormat("合并仓 ID=%I64d 的第 %d 档状态无效，停止自动拆分以避免误平仓。", positionIdentifier, next + 1);
            return;
        }
        if(bid + 0.5 * _Point < target) return;

        ticket = FindOpenPositionTicketByIdentifier(positionIdentifier, mergedMagic);
        if(ticket == 0)
        {
            // 已由人工或 EA 完全结算退出流程清空时，删除孤儿状态，绝不迁移到别的仓位。
            ClearActiveMergeState(mergedMagic, positionIdentifier);
            return;
        }
        if(!PositionSelectByTicket(ticket)) return;

        double currentVolume = PositionGetDouble(POSITION_VOLUME);
        bool closed = false;
        trade.SetExpertMagicNumber(mergedMagic);
        if(currentVolume <= unitVolume + VolumeTolerance())
            closed = ConfirmTradeResult(trade.PositionClose(ticket), "合并仓原止盈阶梯整笔拆分", ticket);
        else
            closed = ConfirmTradeResult(trade.PositionClosePartial(ticket, NormalizeDouble(unitVolume, 8)),
                                        "合并仓原止盈阶梯拆分一单位", ticket);
        if(!closed) return;

        next++;
        GlobalVariableSet(MergeActiveKey(mergedMagic, positionIdentifier, "N"), next);
        PrintFormat("合并仓 ID=%I64d 已在 %.3f 对应的原碎单止盈阶梯拆分第 %d/%d 单位。",
                    positionIdentifier, target, next, count);
    }

    if(next >= count)
        ClearActiveMergeState(mergedMagic, positionIdentifier);
}

void ProcessMergedBatchSplits()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        ulong mergedMagic = PositionGetInteger(POSITION_MAGIC);
        if(PositionGetString(POSITION_SYMBOL) != _Symbol || !IsMergedMagic(mergedMagic) ||
           PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;

        long positionIdentifier = PositionGetInteger(POSITION_IDENTIFIER);
        if(HasActiveMergeState(mergedMagic, positionIdentifier))
            ProcessOneMergedBatchSplit(ticket, mergedMagic, positionIdentifier, bid);
        else
        {
            string warningKey = MergeActiveKey(mergedMagic, positionIdentifier, "W");
            if(!GlobalVariableCheck(warningKey))
            {
                PrintFormat("合并仓 ID=%I64d 缺少原始阶梯；保留持仓，不按新参数补造拆分规则。", positionIdentifier);
                GlobalVariableSet(warningKey, 1);
            }
        }
    }
}

void ManageOrderConsolidation()
{
    // 紧急警戒只用于面板/人工关注；它绝不允许少于阈值或多于阈值地合并。
    if(CountMergeableSmallPositions(InpBaseGridMagic) >= InpMergeThreshold && !HasPendingMerge(InpBaseGridMagic))
        StartMergePlan(InpBaseGridMagic, InpBaseMergedMagic);
    for(int r = 0; r < 3; r++)
        if(CountMergeableSmallPositions(regions[r].magic) >= InpMergeThreshold && !HasPendingMerge(regions[r].magic))
            StartMergePlan(regions[r].magic, regions[r].mergedMagic);
}

//+------------------------------------------------------------------+
bool CheckLevelExists(double t, ulong m, double i)
{
    for(int p=0; p<PositionsTotal(); p++)
        if(PositionSelectByTicket(PositionGetTicket(p)) && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==m && MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-t)<i*0.2) return true;
    for(int o=0; o<OrdersTotal(); o++)
        if(OrderSelect(OrderGetTicket(o)) && OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==m && MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-t)<i*0.2) return true;
    return false;
}
//+------------------------------------------------------------------+
