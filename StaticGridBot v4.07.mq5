//+------------------------------------------------------------------+
//|                                          StaticGridBot v4.07.mq5 |
//|                                      Gold Investor Research 专属 |
//|                                      实盘双核版 v4.07             |
//+------------------------------------------------------------------+
#property copyright "Gold Investor Research"
#property link      ""
#property version   "4.07"
#property strict

#include <Trade\Trade.mqh>

// 每次向服务器发交易请求前，先把已改动的状态写进硬盘，防止请求发出后恰逢断电而重复下单。
class CStateSafeTrade : public CTrade
{
public:
    virtual bool OrderSend(const MqlTradeRequest &request, MqlTradeResult &result)
    {
        FlushStateIfDirty();
        return CTrade::OrderSend(request, result);
    }
};
CStateSafeTrade trade;

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

//====================================================================
// [6] 手机推送（需先在 MT5「工具→选项→通知」填写手机 MetaQuotes ID）
//====================================================================
input group "=== 6. 手机推送 ===";
input bool     InpPushEnabled       = true;       // 手机推送总开关
input bool     InpPushExit          = true;       // 推送：完全结算退出（触发、完成、等待确认）
input bool     InpPushRisk          = true;       // 推送：安全灯变黄、变红、恢复安全
input bool     InpPushMerge         = true;       // 推送：合并与止盈阶梯异常
input bool     InpPushTradeFail     = true;       // 推送：交易请求连续失败
input bool     InpPushSystem        = true;       // 推送：系统状态（断线超3分钟、底仓记录恢复、挂单达上限、保证金不足）
input bool     InpPushMergeDone     = false;      // 推送：每批合并完成
input bool     InpPushDaily         = false;      // 推送：每日收益小结（新交易日第一笔报价时）

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
string stateScope;
string gvExitArmedName;
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
const int MERGE_FRAGMENT_CLOSE_SENT   = 3;     // 已发出平仓请求、尚未确认结果
const int MERGE_FRAGMENT_EXCLUDED     = -1;    // 被人工或其他方式平掉：从本批剔除，不买回
const uint RETCODE_CLOSE_ONLY         = 10044; // 经纪商只允许平仓（如每日结算时段）

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

//--- v4.07 启动、状态落盘、推送与收益统计 ---
bool     startupComplete = false;     // 连上服务器并完成持仓/状态核对后才开始交易
bool     startupBlocked = false;      // 用户拒绝完全结算后，等待卸载，不再做任何交易
ulong    connectedSinceMsc = 0;       // 本次观察到已连上服务器的起始时刻
bool     stateDirty = false;          // 有状态写入但尚未强制落盘
datetime lastStateTouch = 0;          // 上次读一遍持久状态的时间（防 4 周过期）
datetime exitPendingSince = 0;        // 本次加载中看到“退出中”的起始时间
int      consecutiveTradeFailures = 0;
string   pushQueue[];
string   pushCooldownKeys[];
datetime pushCooldownTimes[];
ulong    pushSentMsc[];
bool     pushSetupWarned = false;
ulong    pushRetryAfterMsc = 0;
int      riskStateCandidate = -1;     // 0=安全，1=追保警告，2=高危，3=数据不可用，4=全部区间关闭
datetime riskStateSince = 0;
int      riskStateNotified = -1;      // -1=尚未建立基线（启动后第一次稳定状态不推送）
double   statTodayProfit = 0, statMonthProfit = 0, statMonthSwap = 0;
bool     statValid = false;
datetime statLastCalc = 0;
datetime lastSummaryDayStart = 0;
datetime startupCompletedAt = 0;
datetime gridPlacementPausedUntil = 0;
ulong    disconnectedSinceMsc = 0;
bool     disconnectNotified = false;

//+------------------------------------------------------------------+
//| 手机推送：开关、冷却与平台频率限制                               |
//+------------------------------------------------------------------+
// key 非空时，同一 key 在 cooldownSeconds 内只记录和推送一次，防止逐 tick 刷屏。
void Notify(bool enabled, string key, int cooldownSeconds, string text)
{
    datetime now = TimeLocal();
    if(key != "")
    {
        int index = -1;
        for(int i = 0; i < ArraySize(pushCooldownKeys); i++)
            if(pushCooldownKeys[i] == key) { index = i; break; }
        if(index >= 0 && now - pushCooldownTimes[index] < cooldownSeconds) return;
        if(index < 0)
        {
            index = ArraySize(pushCooldownKeys);
            ArrayResize(pushCooldownKeys, index + 1);
            ArrayResize(pushCooldownTimes, index + 1);
            pushCooldownKeys[index] = key;
        }
        pushCooldownTimes[index] = now;
    }

    Print("【事件】", text);
    if(!InpPushEnabled || !enabled || MQLInfoInteger(MQL_TESTER)) return;
    if(!TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
    {
        if(!pushSetupWarned)
            Print("手机推送未生效：请在 MT5「工具→选项→通知」里填写手机 MetaQuotes ID 并勾选启用。");
        pushSetupWarned = true;
        return;
    }

    string message = "黄金网格 " + _Symbol + "：" + text;
    if(StringLen(message) > 255) message = StringSubstr(message, 0, 255);
    int size = ArraySize(pushQueue);
    if(size >= 20) { ArrayRemove(pushQueue, 0, 1); size--; }
    ArrayResize(pushQueue, size + 1);
    pushQueue[size] = message;
    PumpNotifications();
}

// MT5 限制每秒最多 2 条、每分钟最多 10 条；超出部分留在队列里由计时器稍后发送。
void PumpNotifications()
{
    ulong now = GetTickCount64();
    if(now < pushRetryAfterMsc) return;
    int kept = 0;
    for(int i = 0; i < ArraySize(pushSentMsc); i++)
        if(now - pushSentMsc[i] < 60000) pushSentMsc[kept++] = pushSentMsc[i];
    ArrayResize(pushSentMsc, kept);

    while(ArraySize(pushQueue) > 0)
    {
        int lastSecond = 0;
        for(int i = 0; i < ArraySize(pushSentMsc); i++)
            if(now - pushSentMsc[i] < 1000) lastSecond++;
        if(ArraySize(pushSentMsc) >= 10 || lastSecond >= 2) return;

        ResetLastError();
        if(!SendNotification(pushQueue[0]))
        {
            int error = GetLastError();
            if(error == ERR_NOTIFICATION_TOO_FREQUENT) return;
            if(error == ERR_NOTIFICATION_SEND_FAILED)
            {
                // 多半是网络断开：消息留在队列里，30 秒后重试，恢复联网后补发。
                pushRetryAfterMsc = now + 30000;
                return;
            }
            PrintFormat("手机推送发送失败：error=%d（请检查 MT5 通知设置）", error);
        }
        int sent = ArraySize(pushSentMsc);
        ArrayResize(pushSentMsc, sent + 1);
        pushSentMsc[sent] = now;
        ArrayRemove(pushQueue, 0, 1);
    }
}

void CheckPushSetup()
{
    if(!InpPushEnabled || MQLInfoInteger(MQL_TESTER) || TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED)) return;
    Alert("手机推送已开启，但 MT5 还没设置手机：请在「工具→选项→通知」填写手机 MetaQuotes ID 并勾选启用。");
    pushSetupWarned = true;
}

//+------------------------------------------------------------------+
//| 状态落盘：关键状态改完立刻写盘，防断电或强制重启丢状态           |
//+------------------------------------------------------------------+
// 所有持久状态写入都经过这三个函数；交易请求发出前和每个 tick 结束时统一落盘。
datetime GVSet(string name, double value)
{
    stateDirty = true;
    return GlobalVariableSet(name, value);
}

bool GVDel(string name)
{
    stateDirty = true;
    return GlobalVariableDel(name);
}

int GVDeleteAll(string prefix)
{
    stateDirty = true;
    return GlobalVariablesDeleteAll(prefix);
}

void FlushStateNow()
{
    GlobalVariablesFlush();
    stateDirty = false;
}

void FlushStateIfDirty()
{
    if(stateDirty) FlushStateNow();
}

// 终端全局变量 4 周无人读取会被自动删除；每天把本 EA 的全部状态读一遍。
int TouchStatePrefix(string prefix)
{
    if(StringLen(prefix) == 0) return 0;
    int touched = 0;
    for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
    {
        string name = GlobalVariableName(i);
        if(StringFind(name, prefix) != 0) continue;
        GlobalVariableGet(name);
        touched++;
    }
    return touched;
}

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
    if(sent && IsTradeRetcodeSuccessful())
    {
        consecutiveTradeFailures = 0;
        return true;
    }

    uint code = trade.ResultRetcode();
    PrintFormat("交易失败：%s，ticket=%I64u，retcode=%u，%s",
                action, ticket, code, trade.ResultRetcodeDescription());
    // 请求没真正发出（例如仓位刚被服务器止盈、本地已找不到），回执是上一次的成功码，不计数。
    if(!sent && IsTradeRetcodeSuccessful()) return false;
    // 以下是正常现象，不计入连续失败：仓位已被服务器 TP 先平掉、价格贴近 TP 被冻结、
    // 休市、每日结算只允许平仓、本机关闭自动交易、挂单数达上限（另有专门提醒）。
    if(code == TRADE_RETCODE_POSITION_CLOSED || code == TRADE_RETCODE_FROZEN ||
       code == TRADE_RETCODE_MARKET_CLOSED || code == RETCODE_CLOSE_ONLY ||
       code == TRADE_RETCODE_CLIENT_DISABLES_AT || code == TRADE_RETCODE_LIMIT_ORDERS) return false;
    consecutiveTradeFailures++;
    if(consecutiveTradeFailures >= 10)
        Notify(InpPushTradeFail, "tradefail", 1800,
               StringFormat("交易请求已连续失败 %d 次，最近一次：%s（retcode=%u %s）。请检查网络、账户或参数。",
                            consecutiveTradeFailures, action, code, trade.ResultRetcodeDescription()));
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
    stateScope         = scope;
    gvExitArmedName    = scope + "_ExitArmedPrice";
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
    GVSet(gvName, GlobalStartPrice);
}

void SaveUpperSliceLevel()
{
    GVSet(gvUpperSliceName, (double)highestSlicedLevelUp);
}

void SaveDenseSliceLevel()
{
    GVSet(gvDenseSliceName, (double)lastSlicedLevelDn);
}

void ClearCycleState(bool clearManagedStates = true)
{
    if(GlobalVariableCheck(gvName)) GVDel(gvName);
    if(GlobalVariableCheck(gvUpperSliceName)) GVDel(gvUpperSliceName);
    if(clearManagedStates && GlobalVariableCheck(gvDenseSliceName)) GVDel(gvDenseSliceName);
    if(GlobalVariableCheck(gvExitName)) GVDel(gvExitName);
    if(GlobalVariableCheck(legacyGvName)) GVDel(legacyGvName);
    if(clearManagedStates)
    {
        if(GlobalVariableCheck(gvExitArmedName)) GVDel(gvExitArmedName);
        ClearAllMergeStateScope();
        for(int r = 0; r < 3; r++)
        {
            GVDeleteAll(regions[r].stateKey);
            GVDeleteAll(targetPrefix + StringFormat("%I64u_", regions[r].magic));
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
        GVDel(legacyGvName);
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
    EventKillTimer();
    FlushStateIfDirty();
    PumpNotifications();
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
    GVSet(regions[r].stateKey + "L", regions[r].sliceLevel);
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
        GVSet(key + "P", regions[r].points);
        GVSet(key + "O", InpOffsetPoints);
        GVSet(key + "T", regions[r].top);
        GVSet(key + "B", regions[r].bottom);
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
    GVSet(key + "P", InpBaseGridPoints);
    GVSet(key + "O", InpOffsetPoints);
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
        if(GVSet(key, target) != 0) return target;
        PrintFormat("原始 TP 保存失败，持仓 ID=%I64d，错误=%d", identifier, GetLastError());
        return 0;
    }
    if(!GlobalVariableCheck(key + "W"))
    {
        Notify(InpPushMerge, "", 0, StringFormat("密网持仓 ID=%I64d 找不到原始止盈价；EA 保留它但不会设止盈或合并它，请人工处理。", identifier));
        GVSet(key + "W", 1);
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
//| 底仓记录缺失时先看场内：有初始底仓就按实际价恢复记录，            |
//| 只有其他底仓体系遗留仓就暂停建新底仓，绝不重复买入。              |
//+------------------------------------------------------------------+
bool GuardAgainstDuplicateBase()
{
    if(!HasBaseSystemPosition()) return false;

    double anchor = FindActualBaseAnchor();
    if(anchor > 0)
    {
        GlobalStartPrice = anchor;
        SaveStartPrice();
        if(highestSlicedLevelUp == UNINITIALIZED_LEVEL)
        {
            highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - (double)InpOffsetPoints * _Point) /
                                                   ((double)InpBaseGridPoints * _Point));
            SaveUpperSliceLevel();
        }
        Notify(InpPushSystem, "baserecover", 3600,
               StringFormat("底仓起始价记录丢失，已按场内初始底仓 %s 恢复记录，没有重复建仓。",
                            DoubleToString(anchor, _Digits)));
        return true;
    }

    Notify(InpPushSystem, "baseorphan", 86400,
           "场内有底仓体系的遗留仓位，但找不到起始价记录和初始底仓；已暂停建立新底仓，请人工确认。");
    return true;
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

    if(GuardAgainstDuplicateBase()) return GlobalStartPrice > 0;
    if(openPrice >= InpBaseUpperLimit) return false;
    
    int levels = (int)MathFloor((InpBaseUpperLimit - openPrice) / ((double)InpBaseGridPoints * _Point));
    double vol = NormalizeDouble(levels * InpMinLot, 2);
    
    if(vol > 0)
    {
        double margin = 0;
        if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, vol, openPrice, margin)) margin = 0;
        
        if(margin > 0 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin)
        {
            Notify(InpPushSystem, "", 0, "可用保证金不足，无法建立初始底仓，EA 已停止。");
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
    // 切换周期或改参数时 EA 不会重新加载，这些运行标志必须手动复位。
    startupComplete = false;
    startupBlocked = false;
    connectedSinceMsc = 0;
    exitPendingSince = 0;
    lastStateTouch = 0;
    statValid = false;
    statLastCalc = 0;
    riskStateCandidate = -1;
    riskStateSince = 0;
    riskStateNotified = -1;
    consecutiveTradeFailures = 0;
    lastSummaryDayStart = 0;
    gridPlacementPausedUntil = 0;

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

    CheckPushSetup();
    EventSetTimer(1);
    TryCompleteStartup();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 启动核对：终端开机时 EA 常先于账户同步加载，此时看不到持仓。      |
//| 连上服务器 3 秒后再读状态、核对持仓并开始交易。                   |
//+------------------------------------------------------------------+
// 现价已越过完全结算退出价、此前不在退出中、且这个退出价从没在现价下方生效过（多半是刚填错）：
// 先弹窗确认。同一个退出价此前正常运行过、是关机期间行情真的越过了它，则照常直接退出，不弹窗。
bool ConfirmExitPriceOnStartup(double bid)
{
    if(!IsEAExitTriggered(bid, InpEAExitPrice) || MQLInfoInteger(MQL_TESTER)) return true;
    if(GlobalVariableCheck(gvExitName) && GlobalVariableGet(gvExitName) > 0.5) return true;
    if(GlobalVariableCheck(gvExitArmedName) &&
       MathAbs(GlobalVariableGet(gvExitArmedName) - InpEAExitPrice) < 0.5 * _Point) return true;

    string question = StringFormat("现价 %s 已达到或越过「EA完全结算退出价」%s。\n\n"
                                   "点「是」：立即删除本 EA 全部挂单、市价平掉全部持仓，然后卸载 EA。\n"
                                   "点「否」：不执行任何操作，直接卸载 EA。请检查退出价后重新加载。",
                                   DoubleToString(bid, _Digits), DoubleToString(InpEAExitPrice, _Digits));
    Notify(InpPushExit, "", 0, "现价已越过完全结算退出价，EA 正在电脑上等待你确认是否全部平仓。");
    if(MessageBox(question, "StaticGridBot 完全结算确认", MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) != IDYES)
    {
        startupBlocked = true;
        Alert("已取消完全结算：没有执行任何删单或平仓，EA 已卸载。请修改退出价后重新加载。");
        ExpertRemove();
        return false;
    }
    GVSet(gvExitName, 1.0);
    FlushStateNow();
    Print("已确认完全结算退出：立即开始删单和平仓。");
    return true;
}

bool TryCompleteStartup()
{
    if(startupComplete) return true;
    if(startupBlocked) return false;

    if(!MQLInfoInteger(MQL_TESTER))
    {
        if(!TerminalInfoInteger(TERMINAL_CONNECTED))
        {
            connectedSinceMsc = 0;
            return false;
        }
        if(connectedSinceMsc == 0)
        {
            connectedSinceMsc = GetTickCount64();
            return false;
        }
        if(GetTickCount64() - connectedSinceMsc < 3000) return false;
    }

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(ask <= 0 || bid <= 0) return false;
    if(!ConfirmExitPriceOnStartup(bid)) return false;

    LoadCycleState(bid);
    ReconcileStartState();
    if(!exitInProgress && GlobalStartPrice == 0 && !InpPureDenseMode)
        GuardAgainstDuplicateBase();
    LoadRegionSlices(bid);
    startupComplete = true;
    startupCompletedAt = TimeLocal();
    RefreshPersistentState();

    if(exitInProgress || IsEAExitTriggered(bid, InpEAExitPrice))
    {
        Print("EA 处于完全结算退出状态：禁止新交易，等待删单、平仓与清零核验。");
        FlushStateIfDirty();
        return true;
    }

    // 记住这个退出价已在现价下方生效过；以后若关机期间越过它，重启时直接退出不再弹窗。
    if(InpEAExitPrice > 0) GVSet(gvExitArmedName, InpEAExitPrice);
    else if(GlobalVariableCheck(gvExitArmedName)) GVDel(gvExitArmedName);

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
    CheckPendingOrderCapacity();
    Print("启动核对完成：已与服务器同步持仓和状态，开始正常管理。");
    FlushStateIfDirty();
    return true;
}

//+------------------------------------------------------------------+
//| 每秒计时：完成启动、发送排队推送、每日刷新状态和收益小结          |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(TryCompleteStartup())
    {
        if(TimeLocal() - lastStateTouch >= 86400) RefreshPersistentState();
        if(TimeLocal() - statLastCalc >= 30) UpdateProfitStats();
        CheckDailySummary();
    }
    MonitorConnection();
    PumpNotifications();
    FlushStateIfDirty();
}

//+------------------------------------------------------------------+
//| 主循环引擎 (含 5 秒发包节流阀)                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!TryCompleteStartup()) return;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    if(exitInProgress || IsEAExitTriggered(bid, InpEAExitPrice))
    {
        ProcessExit();
        FlushStateIfDirty();
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
    FlushStateIfDirty();
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
                // 仅运行密网且底仓最高价为 0 时，保留场内旧底仓的原止盈，不把它改成 0。
                if(isBase && InpBaseUpperLimit <= 0) continue;
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
        // 只处理 EA 自己的买入限价挂单；服务器执行止盈时会临时出现同 Magic 的市价单，不能去改它。
        if(OrderSelect(OrderGetTicket(j)) && OrderGetString(ORDER_SYMBOL)==_Symbol &&
           OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_LIMIT)
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
    double openFloating = 0;
    double openSwap = 0;

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
        openFloating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        openSwap += PositionGetDouble(POSITION_SWAP);

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

    string lines[13];
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
        lines[12] = "监控数据不可用：安全状态未判定";
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

        if(highRisk) lines[12] = "高危：极端行情下，防线之上将达到强平条件";
        else if(marginWarning) lines[12] = "警告：跌至底部时将面临追保 (Margin Call)";
        else lines[12] = "安全：按当前推演，物理防线内保证金充足";
        lines[7] = densityText;
        if(bottom <= 0)
        {
            lines[2] = "② 跌至区间底部：不适用（全部区间关闭）";
            lines[3] = "③ 配置满载触底：不适用（全部区间关闭）";
            lines[12] = "全部区间关闭：已有持仓仍按实际仓位管理";
        }
    }

    lines[8] = StringFormat("⑧ 底仓单量：%d，网格单量：%d，网格合并单量：%d，总量：%d",
                            baseCount, gridCount, gridMergedCount, totalCount);
    lines[9] = StringFormat("⑨ 底仓手数：%.2f，网格手数：%.2f，网格合并手数：%.2f，总手数：%.2f",
                            baseVolume, gridVolume, gridMergedVolume, totalVolume);

    if(statValid)
        lines[10] = StringFormat("⑩ 已实现收益：今日 %s，本月 %s；当前浮动 %s",
                                 MoneyText(statTodayProfit), MoneyText(statMonthProfit), MoneyText(openFloating));
    else
        lines[10] = StringFormat("⑩ 已实现收益：统计中；当前浮动 %s", MoneyText(openFloating));
    lines[11] = StringFormat("⑪ 隔夜利息：持仓累计 %s，本月已结算 %s",
                             MoneyText(openSwap), statValid ? MoneyText(statMonthSwap) : "统计中");

    int riskState = 0;
    if(!riskAvailable) riskState = 3;
    else if(bottom <= 0) riskState = 4;
    else if(highRisk) riskState = 2;
    else if(marginWarning) riskState = 1;
    UpdateRiskNotification(riskState, lines[12]);

    int spacing = InpPanelFontSize + 12;
    for(int i = 0; i < 13; i++)
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
        else if(i == 12)
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
        if(OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_LIMIT) continue;   // 服务器执行止盈的临时市价单不能删

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
        GVSet(gvExitName, 1.0);
        Print("已触达EA完全结算退出价，进入退出中状态并冻结全部新交易。");
        Notify(InpPushExit, "", 0, StringFormat("现价已触达完全结算退出价 %s，开始删除全部挂单并平掉全部持仓。",
                                                DoubleToString(InpEAExitPrice, _Digits)));
    }
    if(exitPendingSince == 0) exitPendingSince = TimeLocal();

    int deleted = DeleteAllEAPendingOrders();
    int closed = CloseAllEAPositions();

    if(!HasManagedExposure())
    {
        ClearCycleState();
        Notify(InpPushExit, "", 0, "完全结算已完成：本 EA 的持仓和挂单均已清零，EA 已自动卸载。");
        Alert("EA完全结算退出已确认：本 EA 的持仓和挂单均已清零，现自动卸载 EA。");
        ExpertRemove();
        return;
    }

    if(TimeLocal() - exitPendingSince >= 300)
        Notify(InpPushExit, "exitstuck", 1800,
               "完全结算已进行超过 5 分钟，仍有持仓或挂单没清掉（可能休市或网络问题）；EA 会继续重试，请留意。");
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
    bool placing = TimeLocal() >= gridPlacementPausedUntil;
    if(GlobalStartPrice > 0)
    {
        maxT = (highestSlicedLevelUp - 1) * stepUp + off;
        baseAnchor = GetBaseAnchor();
    }
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong ticket = OrderGetTicket(j);
        if(ticket == 0 || !OrderSelect(ticket) || OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        if(OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_LIMIT) continue;
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
    if(placing && GlobalStartPrice > 0 && !HasPendingMerge(InpBaseGridMagic))
    {
        double current = MathFloor(ask / stepUp) * stepUp;
        trade.SetExpertMagicNumber(InpBaseGridMagic);
        for(int i = 0; i < 100; i++)
        {
            double price = NormalizeDouble(current - i * stepUp + off, _Digits);
            if(price < baseAnchor - 0.001) break;
            if(price > maxT || ask - price < stepUp) continue;
            if(!placing) break;
            if(!CheckLevelExists(price, InpBaseGridMagic, stepUp))
                placing = PlaceGridLimit(InpMinLot, price, price + InpBaseTakeProfit * _Point,
                                         "GridBuy", "铺设底仓回补挂单");
        }
    }
    for(int r = 0; r < 3; r++)
    {
        if(!placing || !regions[r].enabled || HasPendingMerge(regions[r].magic)) continue;
        double step = regions[r].points * _Point;
        trade.SetExpertMagicNumber(regions[r].magic);
        for(int j = 0; j < regions[r].levels; j++)
        {
            double price = DenseCandidatePrice(r, ask, j);
            if(!DenseCandidateAllowed(r, ask, price)) continue;
            if(!placing) break;
            if(!CheckLevelExists(price, regions[r].magic, step))
                placing = PlaceGridLimit(regions[r].lot, price, price + regions[r].takeProfit * _Point,
                                         StringFormat("GridR%d", r + 1), "铺设独立区间挂单");
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
    GVDeleteAll(MergePlanPrefix(sourceMagic));
}

void ClearActiveMergeState(ulong mergedMagic, long positionIdentifier)
{
    GVDeleteAll(MergeActivePrefix(mergedMagic, positionIdentifier));
}

void ClearAllMergeStateScope()
{
    if(StringLen(mergeStateScope) > 0)
        GVDeleteAll(mergeStateScope);
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
        Notify(InpPushMerge, "mergevol" + IntegerToString((long)sourceMagic), 3600,
               StringFormat("合并没有启动：%d 笔碎单合计 %.2f 手，不符合经纪商的手数规格。", selected, combinedVolume));
        return false;
    }

    ClearMergePlan(sourceMagic);
    GVSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_CLOSING);
    GVSet(MergePlanKey(sourceMagic, "M"), (double)mergedMagic);
    GVSet(MergePlanKey(sourceMagic, "C"), selected);

    for(int i = 0; i < selected; i++)
    {
        GVSet(MergePlanFragmentKey(sourceMagic, i, "I"), (double)fragments[i].positionIdentifier);
        GVSet(MergePlanFragmentKey(sourceMagic, i, "V"), fragments[i].volume);
        GVSet(MergePlanFragmentKey(sourceMagic, i, "T"), fragments[i].targetPrice);
        GVSet(MergePlanFragmentKey(sourceMagic, i, "X"), MERGE_FRAGMENT_PENDING);
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

// 锁定批次中的碎单不在场时，按成交历史判断它是怎么平掉的：
// 原始 TP 退出，或被人工等其他方式平掉的，只从本批剔除、不买回；
// 只有 EA 自己为合并而平掉的，才计入合并仓手数。历史尚未同步时先等待。
int ClassifyMissingFragmentExit(long positionIdentifier, double plannedVolume, ulong sourceMagic)
{
    if(!HistorySelectByPosition(positionIdentifier)) return MERGE_FRAGMENT_PENDING;

    bool hasExitDeal = false;
    bool allAtTP = true;
    bool allByThisEA = true;
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
        long reason = HistoryDealGetInteger(dealTicket, DEAL_REASON);
        if(reason != DEAL_REASON_TP) allAtTP = false;
        if(reason != DEAL_REASON_EXPERT || (ulong)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != sourceMagic)
            allByThisEA = false;
    }

    if(!hasExitDeal || exitedVolume + VolumeTolerance() < plannedVolume)
        return MERGE_FRAGMENT_PENDING;
    if(allAtTP) return MERGE_FRAGMENT_CLOSED_AT_TP;
    if(allByThisEA) return MERGE_FRAGMENT_CLOSED_BY_EA;
    return MERGE_FRAGMENT_EXCLUDED;
}

bool ConfirmPlannedFragmentClosures(ulong sourceMagic)
{
    int count = (int)MathRound(ReadMergeState(MergePlanKey(sourceMagic, "C"), 0));
    if(count <= 0)
    {
        Notify(InpPushMerge, "", 0, "合并计划记录异常，已取消该计划，没有建立新合并仓。");
        ClearMergePlan(sourceMagic);
        return false;
    }

    for(int i = 0; i < count; i++)
    {
        int closeState = (int)MathRound(ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "X"),
                                                        MERGE_FRAGMENT_PENDING));
        if(closeState == MERGE_FRAGMENT_CLOSED_BY_EA || closeState == MERGE_FRAGMENT_CLOSED_AT_TP ||
           closeState == MERGE_FRAGMENT_EXCLUDED)
            continue;

        long positionIdentifier = (long)MathRound(ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "I"), 0));
        double plannedVolume = ReadMergeState(MergePlanFragmentKey(sourceMagic, i, "V"), 0);
        ulong ticket = FindOpenPositionTicketByIdentifier(positionIdentifier, sourceMagic);
        if(ticket == 0)
        {
            int exitType = ClassifyMissingFragmentExit(positionIdentifier, plannedVolume, sourceMagic);
            // EA 平仓成交只有在本批已发出平仓请求时才算合并来源；
            // EA 的其他正常动作（越过止盈线的防倒挂平仓、上涨补切减仓）按正常退出剔除，不买回。
            bool eaOtherExit = (exitType == MERGE_FRAGMENT_CLOSED_BY_EA && closeState != MERGE_FRAGMENT_CLOSE_SENT);
            if(eaOtherExit) exitType = MERGE_FRAGMENT_CLOSED_AT_TP;
            if(exitType == MERGE_FRAGMENT_PENDING)
            {
                // 成交历史尚未同步时先等；等满 60 秒仍查不到，按“不买回”处理，宁可少不可多。
                string waitKey = MergePlanFragmentKey(sourceMagic, i, "W");
                if(!GlobalVariableCheck(waitKey)) GVSet(waitKey, (double)TimeLocal());
                datetime waitFrom = (datetime)MathMax(GlobalVariableGet(waitKey), (double)startupCompletedAt);
                if(TimeLocal() - waitFrom < 60) return false;
                exitType = MERGE_FRAGMENT_EXCLUDED;
            }

            GVSet(MergePlanFragmentKey(sourceMagic, i, "X"), exitType);
            if(exitType == MERGE_FRAGMENT_CLOSED_AT_TP)
                PrintFormat("合并计划中的碎单 ID=%I64d 已%s正常退出；该 %.2f 手不纳入本批合并。",
                            positionIdentifier, eaOtherExit ? "由本 EA 止盈/补切" : "由原始 TP",
                            plannedVolume);
            else if(exitType == MERGE_FRAGMENT_CLOSED_BY_EA)
                PrintFormat("合并计划中的碎单 ID=%I64d 已确认由本 EA 平仓，计入本批合并。", positionIdentifier);
            else
                Notify(InpPushMerge, "", 0,
                       StringFormat("合并中有 1 笔碎单（ID=%I64d，%.2f 手）被人工或其他方式平掉，已从本批剔除、不买回；其余碎单照常合并。",
                                    positionIdentifier, plannedVolume));
            continue;
        }

        // 碎单在锁定后被部分减仓过时，按实际剩余手数承接，合并仓不多开。
        if(PositionSelectByTicket(ticket))
        {
            double liveVolume = PositionGetDouble(POSITION_VOLUME);
            if(liveVolume + VolumeTolerance() < plannedVolume)
                GVSet(MergePlanFragmentKey(sourceMagic, i, "V"), liveVolume);
        }
        // 先记下“已发出平仓”（交易请求发出前会写盘），重启后据此确认这笔是 EA 为合并而平的。
        GVSet(MergePlanFragmentKey(sourceMagic, i, "X"), MERGE_FRAGMENT_CLOSE_SENT);
        trade.SetExpertMagicNumber(sourceMagic);
        if(!ConfirmTradeResult(trade.PositionClose(ticket), "关闭已锁定的待合并碎单", ticket)) return false;

        GVSet(MergePlanFragmentKey(sourceMagic, i, "X"), MERGE_FRAGMENT_CLOSED_BY_EA);
    }

    GVSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_OPENING);
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
    GVSet(MergeActiveKey(mergedMagic, positionIdentifier, "C"), count);
    GVSet(MergeActiveKey(mergedMagic, positionIdentifier, "N"), 0.0);
    GVSet(MergeActiveKey(mergedMagic, positionIdentifier, "S"), (double)sourceMagic);
    for(int i = 0; i < count; i++)
    {
        GVSet(MergeActiveUnitKey(mergedMagic, positionIdentifier, i, "T"), units[i].targetPrice);
        GVSet(MergeActiveUnitKey(mergedMagic, positionIdentifier, i, "V"), units[i].volume);
    }

    ClearMergePlan(sourceMagic);
    PrintFormat("合并仓 ID=%I64d 已绑定 %d 个原始止盈阶梯，将从 %.3f 起逐单位拆分。",
                positionIdentifier, count, units[0].targetPrice);
    double mergedVolume = 0;
    for(int i = 0; i < count; i++) mergedVolume += units[i].volume;
    Notify(InpPushMergeDone, "", 0, StringFormat("合并完成：%d 笔碎单合并为 %.2f 手，将从 %s 起按原止盈价逐档拆分。",
                                                 count, mergedVolume, DoubleToString(units[0].targetPrice, _Digits)));
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
        Notify(InpPushMerge, "", 0, "合并计划缺少合并 Magic 记录，已取消该计划，没有建立新合并仓。");
        ClearMergePlan(sourceMagic);
        return false;
    }
    if(volume <= VolumeTolerance())
    {
        Print("已锁定批次中的碎单均已提前退出（原始止盈或被剔除），不建立合并仓。");
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
    GVSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_OPENED_UNBOUND);
    GVSet(MergePlanKey(sourceMagic, "R"), (double)requestTimeMsc);

    trade.SetExpertMagicNumber(mergedMagic);
    string comment = (sourceMagic == InpBaseGridMagic) ? "BaseMerged" : "DownMerged";
    if(!ConfirmTradeResult(trade.Buy(volume, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0, 0, comment),
                           "建立无统一止盈的合并仓", 0))
    {
        // 回执失败不代表一定没成交（网络卡顿时可能已成交）；保持“等待确认”，15 秒后仍找不到合并仓才重发。
        Print("合并仓建仓回执失败；先等待 15 秒确认是否已成交，避免重复开仓。");
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
            GVSet(MergePlanKey(sourceMagic, "S"), MERGE_PENDING_OPENING);
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
            Notify(InpPushMerge, "ladderbad" + IntegerToString(positionIdentifier), 86400,
                   StringFormat("合并仓 ID=%I64d 的第 %d 档止盈记录无效，已停止自动拆分以避免误平仓；剩余仓位需要人工处理。",
                                positionIdentifier, next + 1));
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
        GVSet(MergeActiveKey(mergedMagic, positionIdentifier, "N"), next);
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
            // 刚开出、还没来得及绑定阶梯的合并仓不算异常。
            if(HasPendingMerge(SourceMagicForMerged(mergedMagic))) continue;
            string warningKey = MergeActiveKey(mergedMagic, positionIdentifier, "W");
            if(!GlobalVariableCheck(warningKey))
            {
                Notify(InpPushMerge, "", 0, StringFormat("合并仓 ID=%I64d 找不到原始止盈阶梯记录；EA 保留它但不会自动拆分，请人工处理。",
                                                         positionIdentifier));
                GVSet(warningKey, 1);
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
        if(OrderSelect(OrderGetTicket(o)) && OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==m && OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_LIMIT && MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-t)<i*0.2) return true;
    return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| v4.07 运维：挂单下单、状态保活、挂单上限、收益统计、连接监控     |
//+------------------------------------------------------------------+
ulong SourceMagicForMerged(ulong mergedMagic)
{
    if(mergedMagic == InpBaseMergedMagic) return InpBaseGridMagic;
    int r = RegionForMagic(mergedMagic);
    return r >= 0 ? regions[r].magic : 0;
}

// 返回 false 表示本轮应停止继续挂单：挂单数已达上限、休市、只允许平仓或断线时，逐笔重试只会刷日志。
bool PlaceGridLimit(double lot, double price, double takeProfit, string comment, string action)
{
    if(ConfirmTradeResult(trade.BuyLimit(lot, price, _Symbol, 0, takeProfit, ORDER_TIME_GTC, 0, comment), action, 0))
        return true;

    uint code = trade.ResultRetcode();
    if(code == TRADE_RETCODE_LIMIT_ORDERS)
    {
        gridPlacementPausedUntil = TimeLocal() + 60;
        Notify(InpPushSystem, "orderlimithit", 86400,
               StringFormat("挂单数量已达经纪商上限（%d 笔），部分网格挂单没挂上；EA 每分钟重试一次。",
                            (int)AccountInfoInteger(ACCOUNT_LIMIT_ORDERS)));
        return false;
    }
    if(code == RETCODE_CLOSE_ONLY || code == TRADE_RETCODE_MARKET_CLOSED)
    {
        // 例如每日结算时段经纪商只允许平仓：暂停挂新单 60 秒，避免每 5 秒刷一批失败日志。
        gridPlacementPausedUntil = TimeLocal() + 60;
        return false;
    }
    return !(code == TRADE_RETCODE_CLIENT_DISABLES_AT || code == TRADE_RETCODE_SERVER_DISABLES_AT ||
             code == TRADE_RETCODE_TRADE_DISABLED || code == TRADE_RETCODE_CONNECTION);
}

// 原始止盈记录只刷新仍在场的密网持仓；已平仓的记录不再读取，4 周后由 MT5 自动清理。
void RefreshPersistentState()
{
    int touched = TouchStatePrefix(stateScope) + TouchStatePrefix(mergeStateScope) +
                  TouchStatePrefix(regionStatePrefix);
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        ulong magic = PositionGetInteger(POSITION_MAGIC);
        if(!IsDenseSourceMagic(magic)) continue;
        string key = DenseTargetKey(magic, PositionGetInteger(POSITION_IDENTIFIER));
        if(GlobalVariableCheck(key)) { GlobalVariableGet(key); touched++; }
        if(GlobalVariableCheck(key + "W")) { GlobalVariableGet(key + "W"); touched++; }
    }
    lastStateTouch = TimeLocal();
    PrintFormat("已刷新本 EA 的 %d 条持久状态记录，防止 MT5 自动清理 4 周未读取的记录。", touched);
}

void CheckPendingOrderCapacity()
{
    int limit = (int)AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
    if(limit <= 0) return;

    int planned = 0;
    for(int r = 0; r < 3; r++)
        if(regions[r].enabled) planned += regions[r].levels;
    if(GlobalStartPrice > 0)
    {
        double stepUp = InpBaseGridPoints * _Point;
        double maxT = (highestSlicedLevelUp - 1) * stepUp + InpOffsetPoints * _Point;
        int baseLevels = (int)MathFloor((maxT - GetBaseAnchor()) / stepUp + 0.5) + 1;
        planned += MathMax(0, MathMin(100, baseLevels));
    }

    int others = 0;
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong ticket = OrderGetTicket(j);
        if(ticket == 0 || !OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) == _Symbol && IsManagedMagic(OrderGetInteger(ORDER_MAGIC))) continue;
        others++;
    }
    if(planned + others <= limit) return;

    string text = StringFormat("按当前设置最多需要 %d 笔网格挂单，账户里其他挂单 %d 笔，超过经纪商上限 %d 笔，超出部分会挂不上。请减少层数或关闭部分区间。",
                               planned, others, limit);
    Notify(InpPushSystem, "orderlimit", 86400, text);
    Alert(text);
}

double DisplayRate()
{
    string currency = AccountInfoString(ACCOUNT_CURRENCY);
    StringToUpper(currency);
    return (StringFind(currency, "USC") >= 0 || StringFind(currency, "CENT") >= 0) ? 100.0 : 1.0;
}

string MoneyText(double value)
{
    return StringFormat("%s$%.2f", value < -0.000001 ? "-" : "", MathAbs(value) / DisplayRate());
}

datetime MonthStartOf(datetime time)
{
    MqlDateTime t;
    TimeToStruct(time, t);
    t.day = 1; t.hour = 0; t.min = 0; t.sec = 0;
    return StructToTime(t);
}

// 统计 [from, to] 内本 EA 的已实现盈亏（含隔夜利息、手续费），splitAt 之后的部分另外累计。
bool SumRealized(datetime from, datetime to, datetime splitAt,
                 double &total, double &totalSwap, double &afterSplit, double &afterSplitSwap)
{
    total = 0; totalSwap = 0; afterSplit = 0; afterSplitSwap = 0;
    if(!HistorySelect(from, to)) return false;
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong deal = HistoryDealGetTicket(i);
        if(deal == 0) continue;
        if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
           !IsManagedMagic(HistoryDealGetInteger(deal, DEAL_MAGIC))) continue;
        long type = HistoryDealGetInteger(deal, DEAL_TYPE);
        if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;

        double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
        double value = HistoryDealGetDouble(deal, DEAL_PROFIT) + swap +
                       HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_FEE);
        total += value;
        totalSwap += swap;
        if((datetime)HistoryDealGetInteger(deal, DEAL_TIME) >= splitAt)
        {
            afterSplit += value;
            afterSplitSwap += swap;
        }
    }
    return true;
}

void UpdateProfitStats()
{
    statLastCalc = TimeLocal();
    datetime now = TimeCurrent();
    if(now <= 0) return;
    datetime dayStart = now - now % 86400;
    double month = 0, monthSwap = 0, today = 0, todaySwap = 0;
    statValid = SumRealized(MonthStartOf(now), now + 86400, dayStart, month, monthSwap, today, todaySwap);
    if(!statValid) return;
    statMonthProfit = month;
    statMonthSwap = monthSwap;
    statTodayProfit = today;
}

void CheckDailySummary()
{
    datetime now = TimeCurrent();
    if(now <= 0) return;
    datetime dayStart = now - now % 86400;
    if(lastSummaryDayStart == 0 || dayStart < lastSummaryDayStart)
    {
        lastSummaryDayStart = dayStart;
        return;
    }
    if(dayStart == lastSummaryDayStart) return;

    datetime previousStart = lastSummaryDayStart;
    lastSummaryDayStart = dayStart;
    if(!InpPushEnabled || !InpPushDaily) return;

    double month = 0, monthSwap = 0, day = 0, daySwap = 0;
    if(!SumRealized(MonthStartOf(previousStart), dayStart - 1, previousStart, month, monthSwap, day, daySwap)) return;

    int count = 0;
    double volume = 0, floating = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != _Symbol ||
           !IsManagedMagic(PositionGetInteger(POSITION_MAGIC))) continue;
        count++;
        volume += PositionGetDouble(POSITION_VOLUME);
        floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    }
    Notify(InpPushDaily, "", 0,
           StringFormat("每日小结：上个交易日已实现 %s（其中隔夜利息 %s），当月累计 %s；当前持仓 %d 笔 / %.2f 手，浮动 %s。",
                        MoneyText(day), MoneyText(daySwap), MoneyText(month), count, volume, MoneyText(floating)));
}

// 安全灯状态持续 60 秒才算数，避免价格在边界来回时反复推送；启动后的第一个稳定状态只作基线。
void UpdateRiskNotification(int state, string statusText)
{
    datetime now = TimeLocal();
    if(state != riskStateCandidate)
    {
        riskStateCandidate = state;
        riskStateSince = now;
        return;
    }
    if(now - riskStateSince < 60) return;
    if(riskStateNotified < 0 || riskStateNotified == 4 || state == 4)
    {
        riskStateNotified = state;
        return;
    }
    if(state == riskStateNotified) return;

    string text = "安全灯恢复绿色：" + statusText;
    if(state == 1) text = "安全灯变黄：" + statusText;
    else if(state == 2) text = "安全灯变红：" + statusText;
    else if(state == 3) text = "风控数据不可用，安全状态无法判定，请检查 MT5。";
    riskStateNotified = state;
    Notify(InpPushRisk, "", 0, text);
}

void MonitorConnection()
{
    if(MQLInfoInteger(MQL_TESTER)) return;
    if(TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        if(disconnectNotified) Notify(InpPushSystem, "", 0, "已重新连上交易服务器，EA 恢复正常管理。");
        disconnectedSinceMsc = 0;
        disconnectNotified = false;
        return;
    }
    if(disconnectedSinceMsc == 0)
    {
        disconnectedSinceMsc = GetTickCount64();
        return;
    }
    if(!disconnectNotified && GetTickCount64() - disconnectedSinceMsc >= 180000)
    {
        Notify(InpPushSystem, "", 0, "与交易服务器断开已超过 3 分钟：服务器上的挂单和止盈照常有效，合并仓拆分等要等恢复连接。");
        disconnectNotified = true;
    }
}
//+------------------------------------------------------------------+
