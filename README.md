# SeaTrack - Automated SeaBank Expense Tracker

A Flutter application that automatically tracks SeaBank transactions by intercepting push notifications and syncing them directly to a Supabase PostgreSQL database.

## Prerequisites
- Flutter SDK (>=3.0.0)
- Supabase account and project

## Installation & Setup

1. **Generate Flutter Boilerplate**
   Since this repository contains the core application logic and configuration files, you first need to generate the platform-specific boilerplate (`android`, `ios`, etc.). Run the following command in this directory:
   ```bash
   flutter create .
   ```

2. **Configure Supabase Credentials**
   Open `lib/services/supabase_service.dart` and replace the placeholder constants with your actual Supabase URL and Anon Key:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

3. **Database Schema Setup**
   Run the following SQL in your Supabase SQL Editor to create the required table:
   ```sql
   create table transactions (
       id uuid default gen_random_uuid() primary key,
       title text not null,
       amount numeric not null,
       type text check (type in ('income', 'expense')) not null,
       category text default 'Automated',
       created_at timestamp with time zone default timezone('utc'::text, now()) not null
   );
   ```

4. **Install Dependencies**
   ```bash
   flutter pub get
   ```

5. **Run the App**
   Connect a physical Android device (notification listener testing requires a physical device or a well-configured emulator) and run:
   ```bash
   flutter run
   ```

## Features
- **Background Notification Listener**: Uses `notification_listener_service` to listen to notifications, bypassing active memory limits.
- **Doze Mode Bypass**: Uses `android_power_manager` to prompt the user to ignore battery optimizations, preventing Android from killing the background service.
- **Smart Regex Parser**: Automatically identifies if a SeaBank notification is an Income (Transfer Masuk / Bunga) or Expense (Transfer Keluar / QRIS) and extracts the exact numeric amount.
- **Supabase Sync Engine**: Automatically sends the extracted data securely to the cloud.

## UI Flow
1. Open the app to view the "SeaTrack Dashboard".
2. You will see two permission indicators: **Notification Access** and **Battery Optimization Bypass**.
3. If they are not active, tap **Enable Permission** on each to grant the necessary OS-level access.
4. Keep the app installed. When a SeaBank transaction notification arrives, it will automatically parse the data, sync it to Supabase, and display the action in the Log Monitor at the bottom of the dashboard.
