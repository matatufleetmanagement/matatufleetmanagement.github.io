
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fleetmanagement/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';




import '../admin/view/dashboard.dart';
import '../driver/dashboard.dart';
import 'authpage.dart';



class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder:  (context, snapshot){
          if(snapshot.hasData){
            return   UserChooser();

          } else{
            return const AuthPage(  );
          }
        },
      ),
    );
  }
}



class UserChooser extends StatefulWidget {
  const UserChooser({super.key});

  @override
  State<UserChooser> createState() => _UserChooserState();
}

class _UserChooserState extends State<UserChooser> {
  final user = FirebaseAuth.instance.currentUser!;
  @override
  Widget build(BuildContext context) {
    return Container(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin')
            .where('email', isEqualTo: user.email!)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Text('Loading...');
          }

          if (snapshot.data!.docs.isEmpty) {
            // Data not found in "" table, fetch from "users" table instead
            return FleetDriverDashboard();
          }

          //String image = snapshot.data!.docs[0].get('artistname');

          return FleetDriverDashboard();
        },
      ),
    );
  }
}
