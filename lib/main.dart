import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF173B83);
const blue = Color(0xFF356AE6);
const pale = Color(0xFFF3F6FC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ItepApp());
}

class Question {
  final int id, answer;
  final String category, topic, prompt, translation, explanation;
  final List<String> options;
  final String? passage;
  Question.fromJson(Map<String, dynamic> j)
      : id = j['id'], answer = j['answer'], category = j['category'],
        topic = j['topic'], prompt = j['prompt'],
        translation = j['translation'], explanation = j['explanation'],
        options = List<String>.from(j['options']), passage = j['passage'];
}

class ItepApp extends StatefulWidget {
  const ItepApp({super.key});
  @override
  State<ItepApp> createState() => _ItepAppState();
}

class _ItepAppState extends State<ItepApp> {
  List<Question> questions = [];
  Map<int, List<bool>> history = {};
  Map<String, int> daily = {};
  bool loaded = false;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/questions.json');
    final prefs = await SharedPreferences.getInstance();
    final decoded = (jsonDecode(raw) as List).map((e) => Question.fromJson(e)).toList();
    final saved = prefs.getString('history');
    final savedDaily = prefs.getString('daily');
    setState(() {
      questions = decoded;
      if (saved != null) {
        final m = jsonDecode(saved) as Map<String, dynamic>;
        history = m.map((k,v) => MapEntry(int.parse(k), List<bool>.from(v)));
      }
      if (savedDaily != null) daily = Map<String,int>.from(jsonDecode(savedDaily));
      loaded = true;
    });
  }
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('history', jsonEncode(history.map((k,v)=>MapEntry(k.toString(),v))));
    await p.setString('daily', jsonEncode(daily));
  }
  void record(Question q, bool correct) {
    history.putIfAbsent(q.id, () => []).add(correct);
    final day = DateFormat('yyyy-MM-dd').format(DateTime.now());
    daily[day] = (daily[day] ?? 0) + 1;
    _save(); setState(() {});
  }
  int get completed => history.keys.length;
  int get secondTried => history.values.where((v)=>v.length>=2).length;
  int get secondCorrect => history.values.where((v)=>v.length>=2 && v[1]).length;
  int get secondWrong => history.values.where((v)=>v.length>=2 && !v[1]).length;
  double get secondSuccess => secondTried == 0 ? 0 : (secondCorrect / secondTried * 100).clamp(0,100).toDouble();
  double get secondFailure => secondTried == 0 ? 0 : (secondWrong / secondTried * 100).clamp(0,100).toDouble();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'iTEP B2 Trainer',
    theme: ThemeData(useMaterial3:true, colorScheme: ColorScheme.fromSeed(seedColor: navy), scaffoldBackgroundColor: pale,
      fontFamily: 'Roboto', appBarTheme: const AppBarTheme(backgroundColor:pale, foregroundColor:navy, elevation:0)),
    home: !loaded ? const Scaffold(body:Center(child:CircularProgressIndicator())) : HomePage(
      questions:questions, history:history, completed:completed, secondSuccess:secondSuccess,
      secondFailure:secondFailure, onRecord:record, onRefresh:()=>setState((){}),
      daily:daily),
  );
}

class HomePage extends StatelessWidget {
  final List<Question> questions; final Map<int,List<bool>> history; final int completed;
  final double secondSuccess, secondFailure; final void Function(Question,bool) onRecord;
  final VoidCallback onRefresh; final Map<String,int> daily;
  const HomePage({super.key,required this.questions,required this.history,required this.completed,
    required this.secondSuccess,required this.secondFailure,required this.onRecord,required this.onRefresh,
    required this.daily});
  @override Widget build(BuildContext context) {
    final pct = completed/250*100;
    return Scaffold(body: SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,14,20,16), child:Column(
      crossAxisAlignment:CrossAxisAlignment.start, children:[
        Row(children:[const Icon(Icons.school_rounded,color:navy,size:28),const SizedBox(width:9),
          const Expanded(child:Text('iTEP B2 TRAINER',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.1,color:navy,fontSize:17))),
          Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:const Text('250 SORU',style:TextStyle(color:navy,fontWeight:FontWeight.bold,fontSize:11))) ]),
        const SizedBox(height:19),
        Text('İlerlemen',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800,color:navy)),
        const SizedBox(height:12),
        _ProgressCard(title:'Tamamlanan sorular',value:pct,detail:'$completed / 250 soru',color:blue),
        const SizedBox(height:10),
        _ProgressCard(title:'İkinci denemede doğru',value:secondSuccess,detail:'İlk denemede yanlış yaptıklarının ${secondSuccess.toStringAsFixed(0)}%’i',color:const Color(0xFF159B72)),
        const SizedBox(height:10),
        _ProgressCard(title:'İkinci denemede yine yanlış',value:secondFailure,detail:'İkinci denemeye girenlerin ${secondFailure.toStringAsFixed(0)}%’i',color:const Color(0xFFE18A35)),
        const Spacer(),
        _HomeButton(icon:Icons.insights_rounded,label:'İstatistikler',color:const Color(0xFF516A9C),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StatsPage(questions:questions,history:history,daily:daily)))),
        const SizedBox(height:10),
        _HomeButton(icon:Icons.replay_rounded,label:'Yanlışlar',color:const Color(0xFFD17B39),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>WrongPage(questions:questions,history:history,onRecord:onRecord)))),
        const SizedBox(height:10),
        _HomeButton(icon:Icons.play_arrow_rounded,label:'Devam et',color:navy,primary:true,onTap:(){
          final remaining=questions.where((q)=>!history.containsKey(q.id)).toList();
          if(remaining.isEmpty){
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('250 sorunun tamamını bitirdin! Yanlışlar bölümünden tekrar çalışabilirsin.')));
            return;
          }
          Navigator.push(context,MaterialPageRoute(builder:(_)=>QuizPage(questions:questions,history:history,onRecord:onRecord,startQuestion:remaining.first,allMode:true,queue:remaining))).then((_){onRefresh();});
        }),
      ]))),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title,detail; final double value; final Color color;
  const _ProgressCard({required this.title,required this.value,required this.detail,required this.color});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Expanded(child:Text(title,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13,color:Color(0xFF253653)))),Text('${value.toStringAsFixed(0)}%',style:TextStyle(fontWeight:FontWeight.w900,color:color,fontSize:15))]),
    const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(value:(value/100).clamp(0,1).toDouble(),minHeight:8,backgroundColor:pale,color:color)),
    const SizedBox(height:5),Text(detail,style:TextStyle(color:Colors.blueGrey.shade500,fontSize:10)),
  ]));
}
class _HomeButton extends StatelessWidget {
 final IconData icon; final String label; final Color color; final bool primary; final VoidCallback onTap;
 const _HomeButton({required this.icon,required this.label,required this.color,required this.onTap,this.primary=false});
 @override Widget build(BuildContext context)=>SizedBox(height:primary?54:47,width:double.infinity,child:FilledButton.icon(
  style:FilledButton.styleFrom(backgroundColor:color,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
  onPressed:onTap,icon:Icon(icon,size:20),label:Text(label,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14))));
}

class QuizPage extends StatefulWidget {
 final List<Question> questions; final Map<int,List<bool>> history; final void Function(Question,bool) onRecord;
 final Question startQuestion; final bool allMode; final List<Question>? queue;
 const QuizPage({super.key,required this.questions,required this.history,required this.onRecord,required this.startQuestion,this.allMode=false,this.queue});
 @override State<QuizPage> createState()=>_QuizPageState();
}
class _QuizPageState extends State<QuizPage>{
 late List<Question> list; int index=0; int? selected; bool submitted=false;
 Question get q=>list[index];
 @override void initState(){super.initState();list=widget.queue??widget.questions.where((e)=>e.id>=widget.startQuestion.id).toList(); if(list.isEmpty)list=[widget.startQuestion];}
 void choose(int i){if(submitted)return;setState(()=>selected=i);final ok=i==q.answer;widget.onRecord(q,ok);setState(()=>submitted=true);}
 void next(){if(index+1<list.length){setState((){index++;selected=null;submitted=false;});}else if(widget.allMode){final remaining=widget.questions.where((x)=>!widget.history.containsKey(x.id)).toList(); if(remaining.isNotEmpty){setState((){list=remaining;index=0;selected=null;submitted=false;});}else{Navigator.pop(context);}}else{Navigator.pop(context);}}
 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: Text('Soru ${q.id} / 250'),
       leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
     ),
     body: SafeArea(
       child: Column(children: [
         LinearProgressIndicator(value: (index + 1) / list.length, minHeight: 4, backgroundColor: Colors.white, color: blue),
         Expanded(
           child: ListView(
             padding: const EdgeInsets.all(20),
             children: [
               Row(children: [_tag(q.category), const SizedBox(width: 7), _tag(q.topic)]),
               if (q.passage != null) ...[
                 const SizedBox(height: 15),
                 Container(
                   padding: const EdgeInsets.all(15),
                   decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                   child: Text(q.passage!, style: const TextStyle(height: 1.5, fontSize: 13, color: Color(0xFF46536B))),
                 ),
               ],
               const SizedBox(height: 20),
               Text(q.prompt, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.35, color: Color(0xFF172B4D))),
               const SizedBox(height: 19),
               ...List.generate(q.options.length, (i) => Padding(
                 padding: const EdgeInsets.only(bottom: 10),
                 child: _OptionTile(
                   letter: String.fromCharCode(65 + i), text: q.options[i], selected: selected == i,
                   correct: submitted && i == q.answer, wrong: submitted && selected == i && i != q.answer,
                   onTap: () => choose(i),
                 ),
               )),
               if (submitted) ...[
                 const SizedBox(height: 10),
                 Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: selected == q.answer ? const Color(0xFFE7F6EF) : const Color(0xFFFFEFEC),
                     borderRadius: BorderRadius.circular(16),
                   ),
                   child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                     Row(children: [
                       Icon(selected == q.answer ? Icons.check_circle : Icons.cancel, color: selected == q.answer ? Colors.green : Colors.red),
                       const SizedBox(width: 8),
                       Text(selected == q.answer ? 'Doğru cevap!' : 'Yanlış cevap', style: TextStyle(fontWeight: FontWeight.w900, color: selected == q.answer ? Colors.green.shade800 : Colors.red.shade800)),
                     ]),
                     const SizedBox(height: 12),
                     const Text('Türkçe anlamı', style: TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 4),
                     Text(q.translation, style: const TextStyle(height: 1.4)),
                     const SizedBox(height: 12),
                     const Text('Neden bu cevap?', style: TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 4),
                     Text(q.explanation, style: const TextStyle(height: 1.45)),
                     const SizedBox(height: 8),
                     Text('Doğru cevap: ${String.fromCharCode(65 + q.answer)} — ${q.options[q.answer]}', style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
                   ]),
                 ),
                 const SizedBox(height: 14),
                 SizedBox(
                   width: double.infinity, height: 50,
                   child: FilledButton(
                     onPressed: next,
                     style: FilledButton.styleFrom(backgroundColor: navy),
                     child: Text(index + 1 < list.length ? 'Bir sonraki soruya geç' : 'Bitir'),
                   ),
                 ),
               ],
             ],
           ),
         ),
       ]),
     ),
   );
 }
 Widget _tag(String s)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0xFFE5ECFA),borderRadius:BorderRadius.circular(20)),child:Text(s,style:const TextStyle(color:navy,fontSize:11,fontWeight:FontWeight.bold)));
}
class _OptionTile extends StatelessWidget{
 final String letter,text;final bool selected,correct,wrong;final VoidCallback onTap;
 const _OptionTile({required this.letter,required this.text,required this.selected,required this.correct,required this.wrong,required this.onTap});
 @override Widget build(BuildContext context){final c=correct?Colors.green:wrong?Colors.red:selected?blue:Colors.white;return Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(13),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:c==Colors.white?Colors.white:c.withOpacity(.09),border:Border.all(color:correct?Colors.green:wrong?Colors.red:selected?blue:Colors.white,width:1.5),borderRadius:BorderRadius.circular(13)),child:Row(children:[Container(width:29,height:29,alignment:Alignment.center,decoration:BoxDecoration(color:correct?Colors.green:wrong?Colors.red:selected?blue:pale,shape:BoxShape.circle),child:Text(letter,style:TextStyle(color:correct||wrong||selected?Colors.white:navy,fontWeight:FontWeight.bold))),const SizedBox(width:12),Expanded(child:Text(text,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,color:Color(0xFF243550)))),if(correct)const Icon(Icons.check_circle,color:Colors.green)else if(wrong)const Icon(Icons.cancel,color:Colors.red)]))));}
}

class WrongPage extends StatelessWidget{
 final List<Question> questions;final Map<int,List<bool>> history;final void Function(Question,bool) onRecord;
 const WrongPage({super.key,required this.questions,required this.history,required this.onRecord});
 @override Widget build(BuildContext context){final groups=[
  ('İlk denemede yanlış',0),('İkinci denemede yanlış',1),('Üçüncü denemede yanlış',2)];return Scaffold(appBar:AppBar(title:const Text('Yanlışlarım')),body:ListView(padding:const EdgeInsets.all(18),children:[
  const Text('Tekrar çözerek eksiklerini kapat.',style:TextStyle(color:Colors.blueGrey)),const SizedBox(height:15),
  ...groups.map((g){final qs=questions.where((q){final h=history[q.id]??[];return h.length>g.$2&&!h[g.$2];}).toList();return Card(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:ListTile(contentPadding:const EdgeInsets.all(15),title:Text(g.$1,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${qs.length} soru'),trailing:const Icon(Icons.chevron_right,color:navy),onTap:qs.isEmpty?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>QuizPage(questions:questions,history:history,onRecord:onRecord,startQuestion:qs.first,queue:qs)))));})
 ]));}
}

class StatsPage extends StatelessWidget{
 final List<Question> questions;final Map<int,List<bool>> history;final Map<String,int> daily;
 const StatsPage({super.key,required this.questions,required this.history,required this.daily});
 @override Widget build(BuildContext context){final total=history.values.fold<int>(0,(s,v)=>s+v.length);final correct=history.values.fold<int>(0,(s,v)=>s+v.where((x)=>x).length);final accuracy=total==0?0:correct/total*100;final streakDays=daily.keys.length;final best= daily.values.isEmpty?0:daily.values.reduce((a,b)=>a>b?a:b);
 final cats=['Grammar','Vocabulary','Reading'];final catCorrect={for(final c in cats)c:0};final catTotal={for(final c in cats)c:0};for(final q in questions){final h=history[q.id]??[];catTotal[q.category]=(catTotal[q.category]??0)+h.length;catCorrect[q.category]=(catCorrect[q.category]??0)+h.where((e)=>e).length;}
 return Scaffold(appBar:AppBar(title:const Text('İstatistikler')),body:ListView(padding:const EdgeInsets.all(18),children:[
  GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.45,children:[_StatCard('Toplam cevap','$total','Verilen cevap',Icons.quiz),_StatCard('Başarı oranı','${accuracy.toStringAsFixed(0)}%','Tüm denemelerde',Icons.emoji_events),_StatCard('Aktif gün','$streakDays','Çalıştığın farklı gün',Icons.calendar_month),_StatCard('Günlük rekor','$best','Bir günde cevaplanan',Icons.local_fire_department)]),
  const SizedBox(height:18),_chartCard('Günlük çalışma','Son 7 gün',_dailyChart(daily)),
  _chartCard('Konu bazında başarı','Doğru cevap yüzdesi',_categoryChart(cats,catCorrect,catTotal)),
  _chartCard('Soru dağılımı','250 sorunun konu alanları',_distributionChart(questions)),
  _chartCard('Deneme performansı','1., 2. ve 3. deneme doğruluk oranı',_attemptChart(history)),
  _chartCard('Son cevapların durumu','Son denemede doğru / yanlış',_lastResultChart(history)),
  const SizedBox(height:10),Text('Küçük hedef: Bugün $best soruluk rekorunu geçmeyi dene! 🎯',textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold,color:navy)),
 ]));}
 Widget _chartCard(String title,String sub,Widget chart)=>Container(margin:const EdgeInsets.only(bottom:13),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800,color:navy,fontSize:15)),Text(sub,style:const TextStyle(color:Colors.blueGrey,fontSize:11)),const SizedBox(height:16),SizedBox(height:180,child:chart)]));
 Widget _dailyChart(Map<String, int> data) {
   final days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
   return BarChart(BarChartData(
     barGroups: days.asMap().entries.map((entry) => BarChartGroupData(
       x: entry.key,
       barRods: [BarChartRodData(
         toY: (data[DateFormat('yyyy-MM-dd').format(entry.value)] ?? 0).toDouble(),
         color: blue, width: 17, borderRadius: BorderRadius.circular(4),
       )],
     )).toList(),
     titlesData: FlTitlesData(
       leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 25)),
       rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
       topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
       bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(
         padding: const EdgeInsets.only(top: 7),
         child: Text(['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][days[v.toInt()].weekday - 1], style: const TextStyle(fontSize: 10)),
       ))),
     ),
     gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
   ));
 }
 Widget _categoryChart(List<String> cats, Map<String, int> good, Map<String, int> total) {
   return BarChart(BarChartData(
     maxY: 100,
     barGroups: cats.asMap().entries.map((entry) {
       final count = total[entry.value] ?? 0;
       final percent = count == 0 ? 0.0 : (good[entry.value] ?? 0) / count * 100;
       return BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: percent, color: const Color(0xFF159B72), width: 27, borderRadius: BorderRadius.circular(5))]);
     }).toList(),
     titlesData: FlTitlesData(
       leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
       rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
       topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
       bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(
         padding: const EdgeInsets.only(top: 7), child: Text(cats[v.toInt()], style: const TextStyle(fontSize: 9)),
       ))),
     ),
     gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
   ));
 }
 Widget _distributionChart(List<Question> qs) {
   final values = ['Grammar', 'Vocabulary', 'Reading'].map((c) => qs.where((q) => q.category == c).length.toDouble()).toList();
   return PieChart(PieChartData(
     sections: List.generate(3, (i) => PieChartSectionData(value: values[i], title: values[i].toInt().toString(), radius: 58,
       titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), color: [navy, blue, const Color(0xFF159B72)][i])),
     centerSpaceRadius: 25,
   ));
 }
 Widget _attemptChart(Map<int, List<bool>> h) {
   final values = List.generate(3, (i) {
     final attempts = h.values.where((v) => v.length > i).toList();
     return attempts.isEmpty ? 0.0 : attempts.where((v) => v[i]).length / attempts.length * 100;
   });
   return BarChart(BarChartData(
     maxY: 100,
     barGroups: List.generate(3, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: blue, width: 26, borderRadius: BorderRadius.circular(5))])),
     titlesData: FlTitlesData(
       leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
       rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
       topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
       bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(
         padding: const EdgeInsets.only(top: 7), child: Text('${v.toInt() + 1}. deneme', style: const TextStyle(fontSize: 10)),
       ))),
     ),
     gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
   ));
 }
 Widget _lastResultChart(Map<int, List<bool>> h) {
   final good = h.values.where((v) => v.isNotEmpty && v.last).length;
   final bad = h.values.where((v) => v.isNotEmpty && !v.last).length;
   return PieChart(PieChartData(
     sections: [
       PieChartSectionData(value: good.toDouble().clamp(0.01, 999999).toDouble(), title: 'Doğru\n$good', color: const Color(0xFF159B72), radius: 62, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
       PieChartSectionData(value: bad.toDouble().clamp(0.01, 999999).toDouble(), title: 'Yanlış\n$bad', color: const Color(0xFFE18A35), radius: 62, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
     ],
     centerSpaceRadius: 25,
   ));
 }

}
class _StatCard extends StatelessWidget{final String title,value,subtitle;final IconData icon;const _StatCard(this.title,this.value,this.subtitle,this.icon);@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:blue,size:19),const Spacer(),Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:navy)),Text(title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),Text(subtitle,style:const TextStyle(color:Colors.blueGrey,fontSize:9))]));}
