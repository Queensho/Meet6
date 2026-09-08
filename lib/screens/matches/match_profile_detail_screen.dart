import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/api_service.dart';
import '../../services/gift_service.dart';
import '../../services/live_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import '../../widgets/xp_level_ring.dart';
import '../messages/private_chat_screen.dart';

class MatchProfileDetailScreen extends StatefulWidget {
  const MatchProfileDetailScreen({super.key, required this.matchId, required this.profileName, required this.preferences});
  final String matchId;
  final String profileName;
  final MatchingPreferences preferences;
  @override State<MatchProfileDetailScreen> createState() => _MatchProfileDetailScreenState();
}

class _MatchProfileDetailScreenState extends State<MatchProfileDetailScreen> {
  Map<String,dynamic>? profile;
  Map<String,dynamic>? socialSummary;
  bool loading=true;
  String? error;
  int photoIndex=0;
  final PageController _photoController=PageController();

  bool get dark => Theme.of(context).brightness==Brightness.dark;
  Color get page => dark ? const Color(0xFF071022) : const Color(0xFFF9FAFE);
  Color get surface => dark ? const Color(0xFF111B2E) : Colors.white;
  Color get surface2 => dark ? const Color(0xFF172338) : const Color(0xFFF4F5F9);
  Color get ink => dark ? const Color(0xFFF5F7FF) : AppColors.navy;
  Color get muted => dark ? const Color(0xFFAEB8CC) : const Color(0xFF6E768C);
  Color get divider => dark ? const Color(0xFF29364D) : const Color(0xFFE5E8F0);

  @override void initState(){super.initState();_load();}
  @override void dispose(){_photoController.dispose();super.dispose();}

  Future<void> _load() async {
    try {
      final data=await LiveService.matchDetail(widget.matchId);
      final raw=data['profile'];
      final next=raw is Map?Map<String,dynamic>.from(raw):null;
      Map<String,dynamic>? summary;
      final uid=next?['user_id']?.toString()??'';
      if(uid.isNotEmpty){try{final d=await GiftService.userSummary(uid);if(d['summary'] is Map)summary=Map<String,dynamic>.from(d['summary']);}catch(_){}}
      if(!mounted)return;setState((){profile=next;socialSummary=summary;loading=false;error=profile==null?'Profil bulunamadı.':null;});
    } on ApiException catch(e){if(mounted)setState((){loading=false;error=e.message;});}
  }

  List<String> get photos {final r=profile?['photo_urls'];return r is List?r.map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList():const[];}
  List<String> get interests {final r=profile?['interests'];return r is List?r.map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList():const[];}
  String get name=>profile?['display_name']?.toString()??widget.profileName;
  String get userId=>profile?['user_id']?.toString()??'';
  int get profileLevel=>(socialSummary?['profileLevel'] as num?)?.toInt()??1;
  int get profileXp=>(socialSummary?['profileXp'] as num?)?.toInt()??0;
  bool get isOnline=>profile?['online']==true;
  bool get isPremium=>profile?['premium']==true||profile?['is_premium']==true||profile?['premium_active']==true;
  String get locationText=>[profile?['city'],profile?['country']].where((v)=>v!=null&&v.toString().trim().isNotEmpty).map((v)=>v.toString().trim()).join(', ');
  String get cityText {final v=profile?['city']?.toString().trim()??'';return v.isNotEmpty?v:locationText;}
  String get genderText {final v=profile?['gender']?.toString().trim().toLowerCase()??'';if(['male','erkek','man'].contains(v))return 'Erkek';if(['female','kadın','kadin','woman'].contains(v))return 'Kadın';return profile?['gender']?.toString().trim()??'';}

  void _message()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PrivateChatScreen(matchId:widget.matchId,name:name,userId:userId,photoUrl:photos.isEmpty?'':photos.first,isOnline:isOnline)));
  Future<bool?> _confirm(String title,String body)=>showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:surface,title:Text(title,style:TextStyle(color:ink)),content:Text(body,style:TextStyle(color:muted)),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Onayla'))]));
  Future<void> _block() async {if(await _confirm('Kullanıcı engellensin mi?','Bu eşleşme kapanır ve bu kişiyle tekrar eşleşmezsin.')!=true||userId.isEmpty)return;await LiveService.blockUser(userId);if(mounted)Navigator.pop(context);}
  Future<void> _unmatch() async {if(await _confirm('Eşleşme kaldırılsın mı?','Özel sohbet kapanır. Kullanıcı engellenmez.')!=true)return;await LiveService.unmatch(widget.matchId);if(mounted)Navigator.pop(context);}
  Future<void> _report() async {if(userId.isEmpty)return;await LiveService.reportUser(userId,reason:'Rahatsız edici davranış',detail:'Profil detayından bildirildi');if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Şikâyetin inceleme kuyruğuna alındı.')));}
  Future<void> _more() async {final a=await showModalBottomSheet<String>(context:context,backgroundColor:Colors.transparent,builder:(c)=>SafeArea(child:Container(margin:const EdgeInsets.all(12),decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(28),border:Border.all(color:divider)),child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(iconColor:ink,textColor:ink,leading:const Icon(Icons.flag_outlined),title:const Text('Şikâyet et'),onTap:()=>Navigator.pop(c,'report')),ListTile(iconColor:ink,textColor:ink,leading:const Icon(Icons.heart_broken_outlined),title:const Text('Eşleşmeyi kaldır'),onTap:()=>Navigator.pop(c,'unmatch')),ListTile(leading:const Icon(Icons.block_rounded,color:Color(0xFFE24A4A)),title:const Text('Kullanıcıyı engelle',style:TextStyle(color:Color(0xFFE24A4A))),onTap:()=>Navigator.pop(c,'block'))]))));if(a=='report')await _report();if(a=='unmatch')await _unmatch();if(a=='block')await _block();}

  Widget _networkPhoto(String url,{BoxFit fit=BoxFit.cover})=>Image.network(ApiService.absoluteMediaUrl(url),fit:fit,errorBuilder:(_,__,___)=>Container(color:surface2,alignment:Alignment.center,child:Icon(Icons.person_rounded,size:72,color:ink)));
  void _selectPhoto(int i){if(i<0||i>=photos.length)return;setState(()=>photoIndex=i);_photoController.animateToPage(i,duration:const Duration(milliseconds:280),curve:Curves.easeOutCubic);}
  Widget _hero()=>Stack(clipBehavior:Clip.none,children:[AspectRatio(aspectRatio:1.18,child:ClipRRect(borderRadius:BorderRadius.circular(34),child:photos.isEmpty?Container(color:AppColors.lime,alignment:Alignment.center,child:Text(name.isEmpty?'?':name[0].toUpperCase(),style:const TextStyle(fontSize:76,fontWeight:FontWeight.w900,color:AppColors.navy))):PageView.builder(controller:_photoController,itemCount:photos.length,onPageChanged:(i)=>setState(()=>photoIndex=i),itemBuilder:(_,i)=>_networkPhoto(photos[i])))),if(photos.length>1)Positioned(left:16,bottom:16,child:_DarkPill(text:'${photoIndex+1}/${photos.length}')),if(isPremium)Positioned(left:8,bottom:-18,child:Image.asset('assets/images/premium_badge.png',width:88,height:68,fit:BoxFit.contain)),Positioned(right:-8,bottom:-26,child:XpLevelRing(level:profileLevel,totalXp:profileXp,size:72))]);

  Widget _gallery(){if(photos.isEmpty)return const SizedBox.shrink();return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Text('Fotoğraflar (${photos.length})',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:ink)),const Spacer(),Text('Tümünü gör',style:TextStyle(fontSize:13,color:muted,fontWeight:FontWeight.w700)),const SizedBox(width:4),Icon(Icons.chevron_right_rounded,color:muted)]),const SizedBox(height:12),SizedBox(height:82,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:photos.length,separatorBuilder:(_,__)=>const SizedBox(width:9),itemBuilder:(_,i)=>GestureDetector(onTap:()=>_selectPhoto(i),child:AnimatedContainer(duration:const Duration(milliseconds:180),width:72,padding:EdgeInsets.all(i==photoIndex?3:0),decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:i==photoIndex?Border.all(color:AppColors.lime,width:3):null),child:ClipRRect(borderRadius:BorderRadius.circular(14),child:_networkPhoto(photos[i]))))) )]);}

  Widget _sectionTitle(IconData icon,String title)=>Row(children:[_SectionIcon(icon:icon),const SizedBox(width:14),Text(title,style:TextStyle(color:ink,fontSize:18,fontWeight:FontWeight.w900))]);
  Widget _aboutAndInterests(int? age,String bio)=>_CardShell(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_sectionTitle(Icons.article_outlined,'Hakkında'),const SizedBox(height:14),Text(bio.isEmpty?'Henüz hakkında bilgisi eklenmemiş.':bio,style:TextStyle(color:muted,fontSize:14,height:1.45,fontWeight:FontWeight.w600)),if(interests.isNotEmpty)...[const SizedBox(height:20),Divider(height:1,color:divider),const SizedBox(height:18),_sectionTitle(Icons.interests_rounded,'İlgi alanları'),const SizedBox(height:13),Wrap(spacing:8,runSpacing:8,children:interests.map((e)=>_TextChip(text:e)).toList())],const SizedBox(height:20),Divider(height:1,color:divider),const SizedBox(height:18),_sectionTitle(Icons.person_outline_rounded,'Profil bilgileri'),const SizedBox(height:13),Wrap(spacing:8,runSpacing:8,children:[if(age!=null)_InfoChip(icon:Icons.cake_outlined,text:'$age yaş'),if(genderText.isNotEmpty)_InfoChip(icon:Icons.person_outline_rounded,text:genderText),if(cityText.isNotEmpty)_InfoChip(icon:Icons.location_on_rounded,text:cityText),if((profile?['country']?.toString().trim()??'').isNotEmpty)_InfoChip(icon:Icons.public_rounded,text:profile!['country'].toString())])])));
  Widget _profileQuestion(String prompt,String answer)=>_CardShell(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_sectionTitle(Icons.chat_bubble_outline_rounded,'Profil sorum'),const SizedBox(height:14),if(prompt.isNotEmpty)Text(prompt,style:const TextStyle(color:Color(0xFF5C8DFF),fontSize:14,fontWeight:FontWeight.w800)),if(prompt.isNotEmpty&&answer.isNotEmpty)const SizedBox(height:9),if(answer.isNotEmpty)Text(answer,style:TextStyle(color:ink,fontSize:15,height:1.4,fontWeight:FontWeight.w700))]));

  @override Widget build(BuildContext context){final age=(profile?['age'] as num?)?.toInt();final bio=profile?['bio']?.toString().trim()??'';final prompt=profile?['profile_prompt']?.toString().trim()??'';final answer=profile?['profile_answer']?.toString().trim()??'';return Scaffold(backgroundColor:page,body:PhoneFrame(child:loading?const Center(child:CircularProgressIndicator(color:AppColors.lime)):error!=null?Center(child:FilledButton(onPressed:_load,child:Text(error!))):Stack(children:[Positioned(top:-70,right:-90,child:_Blob(size:220,color:dark?const Color(0x243C5A22):const Color(0x1ABFFF24))),Positioned(top:360,left:-100,child:_Blob(size:210,color:dark?const Color(0x182F6BFF):const Color(0x10BFFF24))),SingleChildScrollView(padding:const EdgeInsets.fromLTRB(22,94,22,118),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:_hero()),const SizedBox(height:42),Row(children:[Flexible(child:Text(age==null?name:'$name, $age',style:TextStyle(color:ink,fontSize:29,height:1.05,fontWeight:FontWeight.w900,letterSpacing:-1))),const SizedBox(width:8),const Icon(Icons.verified_rounded,color:Color(0xFF2F6BFF),size:24)]),const SizedBox(height:10),Wrap(spacing:12,runSpacing:7,children:[if(isOnline)const _InlineInfo(icon:Icons.circle,text:'Şu anda aktif',color:Color(0xFF18BF55),iconSize:11),if(locationText.isNotEmpty)_InlineInfo(icon:Icons.location_on_rounded,text:locationText,color:muted)]),const SizedBox(height:26),_gallery(),const SizedBox(height:20),_aboutAndInterests(age,bio),if(prompt.isNotEmpty||answer.isNotEmpty)...[const SizedBox(height:14),_profileQuestion(prompt,answer)]])),Positioned(top:12,left:12,child:SafeArea(child:_CircleButton(icon:Icons.arrow_back_ios_new_rounded,onTap:()=>Navigator.pop(context)))),Positioned(top:12,right:12,child:SafeArea(child:_CircleButton(icon:Icons.more_vert_rounded,onTap:_more))),Positioned(left:18,right:18,bottom:14,child:SafeArea(top:false,child:_MessageButton(onTap:_message))) ]))));}
}

class _CircleButton extends StatelessWidget{const _CircleButton({required this.icon,required this.onTap});final IconData icon;final VoidCallback onTap;@override Widget build(BuildContext context){final d=Theme.of(context).brightness==Brightness.dark;return Material(color:d?const Color(0xFF172338):Colors.white,shape:const CircleBorder(),elevation:d?0:2,child:InkWell(customBorder:const CircleBorder(),onTap:onTap,child:SizedBox(width:56,height:56,child:Icon(icon,color:d?Colors.white:AppColors.navy,size:25))));}}
class _CardShell extends StatelessWidget{const _CardShell({required this.child});final Widget child;@override Widget build(BuildContext context){final d=Theme.of(context).brightness==Brightness.dark;return Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:d?const Color(0xFF111B2E):Colors.white,borderRadius:BorderRadius.circular(28),border:Border.all(color:d?const Color(0xFF29364D):const Color(0xFFE5E8F0)),boxShadow:d?const[]:const[BoxShadow(color:Color(0x0B0B1745),blurRadius:18,offset:Offset(0,7))]),child:child);}}
class _SectionIcon extends StatelessWidget{const _SectionIcon({required this.icon});final IconData icon;@override Widget build(BuildContext context)=>Container(width:48,height:48,decoration:const BoxDecoration(color:AppColors.lime,shape:BoxShape.circle),child:Icon(icon,color:AppColors.navy,size:23));}
class _InfoChip extends StatelessWidget{const _InfoChip({required this.icon,required this.text});final IconData icon;final String text;@override Widget build(BuildContext context){final d=Theme.of(context).brightness==Brightness.dark;final ink=d?const Color(0xFFF5F7FF):AppColors.navy;return Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:BoxDecoration(color:d?const Color(0xFF172338):const Color(0xFFF4F5F9),borderRadius:BorderRadius.circular(999)),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:17,color:ink),const SizedBox(width:7),Text(text,style:TextStyle(color:ink,fontSize:12,fontWeight:FontWeight.w700))]));}}
class _TextChip extends StatelessWidget{const _TextChip({required this.text});final String text;@override Widget build(BuildContext context){final d=Theme.of(context).brightness==Brightness.dark;return Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:9),decoration:BoxDecoration(color:d?const Color(0xFF172338):const Color(0xFFF2F3F7),borderRadius:BorderRadius.circular(999)),child:Text(text,style:TextStyle(color:d?const Color(0xFFF5F7FF):AppColors.navy,fontSize:12,fontWeight:FontWeight.w700)));}}
class _InlineInfo extends StatelessWidget{const _InlineInfo({required this.icon,required this.text,required this.color,this.iconSize=18});final IconData icon;final String text;final Color color;final double iconSize;@override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:color,size:iconSize),const SizedBox(width:5),Text(text,style:TextStyle(color:color,fontSize:13,fontWeight:FontWeight.w700))]);}
class _DarkPill extends StatelessWidget{const _DarkPill({required this.text});final String text;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:AppColors.navy.withValues(alpha:.88),borderRadius:BorderRadius.circular(999)),child:Text(text,style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)));}
class _MessageButton extends StatelessWidget{const _MessageButton({required this.onTap});final VoidCallback onTap;@override Widget build(BuildContext context)=>Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(30),child:Ink(height:62,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFD8FF2F),Color(0xFFBFFF24)]),borderRadius:BorderRadius.circular(30),boxShadow:const[BoxShadow(color:Color(0x35BFFF24),blurRadius:24,offset:Offset(0,9))]),child:const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.send_rounded,color:AppColors.navy,size:25),SizedBox(width:12),Text('Mesaj gönder',style:TextStyle(color:AppColors.navy,fontSize:17,fontWeight:FontWeight.w900))]))));}
class _Blob extends StatelessWidget{const _Blob({required this.size,required this.color});final double size;final Color color;@override Widget build(BuildContext context)=>IgnorePointer(child:Container(width:size,height:size,decoration:BoxDecoration(color:color,shape:BoxShape.circle)));}
