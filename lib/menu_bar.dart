import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomMenuBar extends StatelessWidget {
  const CustomMenuBar({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    // Clear login flag and optionally sign out from FirebaseAuth.
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildMenuItem({
    required IconData iconData,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 2.0),
          ),
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            iconData,
            size: 30, // Increased icon size
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18), // Increased text size
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set drawer width to 75% of screen width.
    final width = MediaQuery.of(context).size.width * 0.75;
    return Drawer(
      child: SafeArea(
        child: Container(
          width: width,
          child: Column(
            children: [
              // Header bar on top without colored background.
              Container(
                width: double.infinity,
                height: 60,
                alignment: Alignment.center,
                child: const Text(
                  "SAATHI",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              // Menu items.
              Expanded(
                child: ListView(
                  children: [
                    _buildMenuItem(
                      iconData: Icons.person,
                      title: "Profile",
                      onTap: () {
                        // Handle Profile tap.
                        Navigator.pop(context);
                      },
                    ),
                    _buildMenuItem(
                      iconData: Icons.info,
                      title: "About SAATHI",
                      onTap: () {
                        // Handle About SAATHI tap.
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              // Logout option at the bottom.
              _buildMenuItem(
                iconData: Icons.logout,
                title: "Logout",
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
