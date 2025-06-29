# corpsapp

Mobile frontend for the Corps App

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

for running ngrok tunnel (Remember to grab the new forward address if the server is restarted as it generated a new address and then replace the variable in the .env)

ngrok http 5133




Usage Example (Anywhere in your app):
final user = context.watch<AuthProvider>().userProfile;
final isAdmin = user?['roles']?.contains('Admin') ?? false;

To log out:
await context.read<AuthProvider>().logout();
Navigator.pushReplacementNamed(context, '/login');


To access profile data:
final name = context.watch<AuthProvider>().userProfile?['firstName'];