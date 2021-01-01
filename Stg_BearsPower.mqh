/**
 * @file
 * Implements BearsPower strategy based on the Bears Power indicator.
 */

// User input params.
INPUT float BearsPower_LotSize = 0;               // Lot size
INPUT int BearsPower_SignalOpenMethod = 0;        // Signal open method (0-
INPUT float BearsPower_SignalOpenLevel = 0.0f;    // Signal open level
INPUT int BearsPower_SignalOpenFilterMethod = 1;  // Signal filter method
INPUT int BearsPower_SignalOpenBoostMethod = 0;   // Signal boost method
INPUT int BearsPower_SignalCloseMethod = 0;       // Signal close method
INPUT float BearsPower_SignalCloseLevel = 0.0f;   // Signal close level
INPUT int BearsPower_PriceStopMethod = 0;         // Price stop method
INPUT float BearsPower_PriceStopLevel = 0;        // Price stop level
INPUT int BearsPower_TickFilterMethod = 1;        // Tick filter method
INPUT float BearsPower_MaxSpread = 4.0;           // Max spread to trade (pips)
INPUT int BearsPower_Shift = 0;                   // Shift (relative to the current bar, 0 - default)
INPUT int BearsPower_OrderCloseTime = -20;        // Order close time in mins (>0) or bars (<0)
INPUT string __BearsPower_Indi_BearsPower_Parameters__ =
    "-- BearsPower strategy: BearsPower indicator params --";  // >>> BearsPower strategy: BearsPower indicator <<<
INPUT int BearsPower_Indi_BearsPower_Period = 13;              // Period
INPUT ENUM_APPLIED_PRICE BearsPower_Indi_BearsPower_Applied_Price = PRICE_CLOSE;  // Applied Price

// Structs.

// Defines struct with default user indicator values.
struct Indi_BearsPower_Params_Defaults : BearsPowerParams {
  Indi_BearsPower_Params_Defaults()
      : BearsPowerParams(::BearsPower_Indi_BearsPower_Period, ::BearsPower_Indi_BearsPower_Applied_Price) {}
} indi_bears_defaults;

// Defines struct to store indicator parameter values.
struct Indi_BearsPower_Params : public BearsPowerParams {
  // Struct constructors.
  void Indi_BearsPower_Params(BearsPowerParams &_params, ENUM_TIMEFRAMES _tf) : BearsPowerParams(_params, _tf) {}
};

// Defines struct with default user strategy values.
struct Stg_BearsPower_Params_Defaults : StgParams {
  Stg_BearsPower_Params_Defaults()
      : StgParams(::BearsPower_SignalOpenMethod, ::BearsPower_SignalOpenFilterMethod, ::BearsPower_SignalOpenLevel,
                  ::BearsPower_SignalOpenBoostMethod, ::BearsPower_SignalCloseMethod, ::BearsPower_SignalCloseLevel,
                  ::BearsPower_PriceStopMethod, ::BearsPower_PriceStopLevel, ::BearsPower_TickFilterMethod,
                  ::BearsPower_MaxSpread, ::BearsPower_Shift, ::BearsPower_OrderCloseTime) {}
} stg_bears_defaults;

// Struct to define strategy parameters to override.
struct Stg_BearsPower_Params : StgParams {
  Indi_BearsPower_Params iparams;
  StgParams sparams;

  // Struct constructors.
  Stg_BearsPower_Params(Indi_BearsPower_Params &_iparams, StgParams &_sparams)
      : iparams(indi_bears_defaults, _iparams.tf), sparams(stg_bears_defaults) {
    iparams = _iparams;
    sparams = _sparams;
  }
};

// Loads pair specific param values.
#include "config/EURUSD_H1.h"
#include "config/EURUSD_H4.h"
#include "config/EURUSD_H8.h"
#include "config/EURUSD_M1.h"
#include "config/EURUSD_M15.h"
#include "config/EURUSD_M30.h"
#include "config/EURUSD_M5.h"

class Stg_BearsPower : public Strategy {
 public:
  Stg_BearsPower(StgParams &_params, string _name) : Strategy(_params, _name) {}

  static Stg_BearsPower *Init(ENUM_TIMEFRAMES _tf = NULL, long _magic_no = NULL, ENUM_LOG_LEVEL _log_level = V_INFO) {
    // Initialize strategy initial values.
    Indi_BearsPower_Params _indi_params(indi_bears_defaults, _tf);
    StgParams _stg_params(stg_bears_defaults);
    if (!Terminal::IsOptimization()) {
      SetParamsByTf<Indi_BearsPower_Params>(_indi_params, _tf, indi_bears_m1, indi_bears_m5, indi_bears_m15,
                                            indi_bears_m30, indi_bears_h1, indi_bears_h4, indi_bears_h8);
      SetParamsByTf<StgParams>(_stg_params, _tf, stg_bears_m1, stg_bears_m5, stg_bears_m15, stg_bears_m30, stg_bears_h1,
                               stg_bears_h4, stg_bears_h8);
    }
    // Initialize indicator.
    BearsPowerParams bears_params(_indi_params);
    _stg_params.SetIndicator(new Indi_BearsPower(_indi_params));
    // Initialize strategy parameters.
    _stg_params.GetLog().SetLevel(_log_level);
    _stg_params.SetMagicNo(_magic_no);
    _stg_params.SetTf(_tf, _Symbol);
    // Initialize strategy instance.
    Strategy *_strat = new Stg_BearsPower(_stg_params, "BearsPower");
    _stg_params.SetStops(_strat, _strat);
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    Chart *_chart = sparams.GetChart();
    Indi_BearsPower *_indi = Data();
    bool _is_valid = _indi[CURR].IsValid() && _indi[PREV].IsValid() && _indi[PPREV].IsValid();
    bool _result = _is_valid;
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    double level = _level * Chart().GetPipSize();
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        // The histogram is above zero level.
        // Fall of histogram, which is above zero, indicates that while the bulls prevail on the market,
        // their strength begins to weaken and the bears gradually increase their pressure.
        _result = _indi[CURR][0] > 0 && _indi.IsIncreasing(3);
        _result &= _indi.IsIncByPct(_level, 0, 0, 2);
          // Signal: Changing from negative values to positive.
        if (_result && _method != 0) {
          if (METHOD(_method, 0)) _result &= _indi.IsIncreasing(2, 0, 3);
          if (METHOD(_method, 1)) _result &= _indi.IsIncreasing(2, 0, 5);
          // When histogram passes through zero level from bottom up,
          // bears have lost control over the market and bulls increase pressure.
          if (METHOD(_method, 2)) _result &= _indi[PPREV][0] < 0;
        }
        break;
      case ORDER_TYPE_SELL:
        // Strong bearish trend - the histogram is located below the central line.
        _result = _indi[CURR][0] < 0 && _indi.IsDecreasing(3);
        _result &= _indi.IsDecByPct(_level, 0, 0, 2);
        if (_result && _method != 0) {
          // When histogram is below zero level, but with the rays pointing upwards (upward trend),
          // then we can assume that, in spite of still bearish sentiment in the market, their strength begins to
          // weaken.
          if (METHOD(_method, 0)) _result &= _indi.IsDecreasing(2, 0, 3);
          if (METHOD(_method, 1)) _result &= _indi.IsDecreasing(2, 0, 5);
          if (METHOD(_method, 2)) _result &= _indi[PPREV][0] > 0;
        }
        break;
    }
    return _result;
  }

  /**
   * Gets price stop value for profit take or stop loss.
   */
  float PriceStop(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, float _level = 0.0) {
    Indi_BearsPower *_indi = Data();
    double _trail = _level * Market().GetPipSize();
    int _direction = Order::OrderDirection(_cmd, _mode);
    double _default_value = Market().GetCloseOffer(_cmd) + _trail * _method * _direction;
    double _result = _default_value;
    switch (_method) {
      case 1: {
        int _bar_count0 = (int)_level * (int)_indi.GetPeriod();
        _result = _direction > 0 ? _indi.GetPrice(PRICE_HIGH, _indi.GetHighest<double>(_bar_count0))
                                 : _indi.GetPrice(PRICE_LOW, _indi.GetLowest<double>(_bar_count0));
        break;
      }
      case 2: {
        int _bar_count1 = (int)_level * (int)_indi.GetPeriod();
        _result = _direction < 0 ? _indi.GetPrice(PRICE_HIGH, _indi.GetHighest<double>(_bar_count1))
                                 : _indi.GetPrice(PRICE_LOW, _indi.GetLowest<double>(_bar_count1));
        break;
      }
    }
    return (float)_result;
  }
};
