import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(TradingApp());

class TradingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(backgroundColor: Colors.grey[900]),
      ),
      home: LiveTradingScreen(),
    );
  }
}

class CandleData {
  final DateTime time;
  final double open, high, low, close;
  CandleData(this.time, this.open, this.high, this.low, this.close);
}

class LiveTradingScreen extends StatefulWidget {
  @override
  _LiveTradingScreenState createState() => _LiveTradingScreenState();
}

class _LiveTradingScreenState extends State<LiveTradingScreen> {
  late WebSocketChannel _depthChannel;
  late WebSocketChannel _klineChannel;
  
  List<List<String>> bids = [];
  List<List<String>> asks = [];
  List<CandleData> candles = [];

  @override
  void initState() {
    super.initState();
    _connectDepth();
    _connectKlines();
  }

  void _connectDepth() {
    _depthChannel = IOWebSocketChannel.connect(
      'wss://stream.binance.com:9443/ws/btcusdt@depth20@100ms',
    );
    _depthChannel.stream.listen((dynamic data) {
      final parsed = jsonDecode(data);
      setState(() {
        bids = List<List<String>>.from(parsed['bids']).take(10).toList();
        asks = List<List<String>>.from(parsed['asks']).take(10).toList();
      });
    });
  }

  void _connectKlines() {
    _klineChannel = IOWebSocketChannel.connect(
      'wss://stream.binance.com:9443/ws/btcusdt@kline_1m',
    );
    _klineChannel.stream.listen((dynamic data) {
      final parsed = jsonDecode(data);
      final k = parsed['k'];
      final candle = CandleData(
        DateTime.fromMillisecondsSinceEpoch(k['t']),
        double.parse(k['o']),
        double.parse(k['h']),
        double.parse(k['l']),
        double.parse(k['c']),
      );
      setState(() {
        candles.add(candle);
        if (candles.length > 300) candles.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _depthChannel.sink.close();
    _klineChannel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('BTC/USDT Live Trader')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 10),
            Container(
              height: 400,
              padding: EdgeInsets.all(8),
              child: _buildChart(),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _buildOrderBook(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (candles.isEmpty) return Center(child: CircularProgressIndicator());
    return SfCartesianChart(
      backgroundColor: Colors.black,
      plotAreaBorderColor: Colors.grey[800],
      primaryXAxis: DateTimeAxis(
        axisLine: AxisLine(color: Colors.grey),
        labelStyle: TextStyle(color: Colors.grey),
      ),
      primaryYAxis: NumericAxis(
        axisLine: AxisLine(color: Colors.grey),
        labelStyle: TextStyle(color: Colors.grey),
      ),
      series: <CandleSeries<CandleData, DateTime>>[
        CandleSeries<CandleData, DateTime>(
          dataSource: candles,
          xValueMapper: (CandleData data, _) => data.time,
          lowValueMapper: (CandleData data, _) => data.low,
          highValueMapper: (CandleData data, _) => data.high,
          openValueMapper: (CandleData data, _) => data.open,
          closeValueMapper: (CandleData data, _) => data.close,
          bullColor: Colors.green,
          bearColor: Colors.red,
          enableTooltip: true,
        )
      ],
    );
  }

  Widget _buildOrderBook() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bids', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ...bids.map((b) => Text('${b[0]}  ${b[1]}', style: TextStyle(color: Colors.white, fontSize: 12))),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asks', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ...asks.map((a) => Text('${a[0]}  ${a[1]}', style: TextStyle(color: Colors.white, fontSize: 12))),
            ],
          ),
        ),
      ],
    );
  }
}
