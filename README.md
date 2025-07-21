# Corps App

Mobile frontend for the Corps App

# Figma Design

https://www.figma.com/design/ziG9kkU6H4YqGJ6Q7ZnHVe/Corps-App?node-id=60-4084&t=HdKXmlkzjMbcbOkK-1

<img width="166" height="357" alt="Homepage - Users   Staff" src="https://github.com/user-attachments/assets/b7d03a97-d975-40b9-bdf3-975d74565628" />
<img width="166" height="357" alt="Booking - Step 3" src="https://github.com/user-attachments/assets/8f260813-1c7a-470e-9c33-9eac0c32112e" />
<img width="166" height="357" alt="Booking Confirmation" src="https://github.com/user-attachments/assets/09ba5c32-df31-469b-a04b-715cd9a6432a" />
<img width="166" height="357" alt="My Tickets" src="https://github.com/user-attachments/assets/f028f3bd-4d07-4f32-a61f-8c8ab0eba7aa" />


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
