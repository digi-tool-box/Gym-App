// Placeholder — regenerate via:
//   supabase gen types --lang=typescript --linked > src/types/supabase.ts
// This file prevents compilation errors until types are generated from the live project.

import type { MergeDeep } from 'type-fest'

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export interface Database {
  public: {
    Tables: {
      tenants: {
        Row: {
          id: string
          name: string
          slug: string
          logo_url: string | null
          address: string | null
          phone: string | null
          email: string | null
          is_active: boolean
          settings: Json
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          name: string
          slug: string
          logo_url?: string | null
          address?: string | null
          phone?: string | null
          email?: string | null
          is_active?: boolean
          settings?: Json
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          name?: string
          slug?: string
          logo_url?: string | null
          address?: string | null
          phone?: string | null
          email?: string | null
          is_active?: boolean
          settings?: Json
          created_at?: string
          updated_at?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          id: string
          tenant_id: string
          role: 'owner' | 'manager' | 'trainer' | 'receptionist'
          full_name: string
          avatar_url: string | null
          phone: string | null
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          tenant_id: string
          role?: 'owner' | 'manager' | 'trainer' | 'receptionist'
          full_name: string
          avatar_url?: string | null
          phone?: string | null
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          role?: 'owner' | 'manager' | 'trainer' | 'receptionist'
          full_name?: string
          avatar_url?: string | null
          phone?: string | null
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'profiles_tenant_id_fkey'
            columns: ['tenant_id']
            referencedRelation: 'tenants'
            referencedColumns: ['id']
          },
        ]
      }
      members: {
        Row: {
          id: string
          tenant_id: string
          code: string
          full_name: string
          email: string | null
          phone: string | null
          photo_url: string | null
          membership_type_id: string | null
          membership_start: string | null
          membership_end: string | null
          is_active: boolean
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          code?: string
          full_name: string
          email?: string | null
          phone?: string | null
          photo_url?: string | null
          membership_type_id?: string | null
          membership_start?: string | null
          membership_end?: string | null
          is_active?: boolean
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          code?: string
          full_name?: string
          email?: string | null
          phone?: string | null
          photo_url?: string | null
          membership_type_id?: string | null
          membership_start?: string | null
          membership_end?: string | null
          is_active?: boolean
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Relationships: []
      }
      membership_types: {
        Row: {
          id: string
          tenant_id: string
          name: string
          duration_days: number
          price: number
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          name: string
          duration_days: number
          price: number
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          name?: string
          duration_days?: number
          price?: number
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Relationships: []
      }
      attendance: {
        Row: {
          id: string
          tenant_id: string
          member_id: string
          check_in: string
          check_out: string | null
          method: 'qr' | 'manual'
          created_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          member_id: string
          check_in?: string
          check_out?: string | null
          method: 'qr' | 'manual'
          created_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          member_id?: string
          check_in?: string
          check_out?: string | null
          method?: 'qr' | 'manual'
          created_at?: string
        }
        Relationships: []
      }
      payments: {
        Row: {
          id: string
          tenant_id: string
          member_id: string
          amount: number
          payment_method: string | null
          notes: string | null
          received_by: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          member_id: string
          amount: number
          payment_method?: string | null
          notes?: string | null
          received_by: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          member_id?: string
          amount?: number
          payment_method?: string | null
          notes?: string | null
          received_by?: string
          created_at?: string
          updated_at?: string
        }
        Relationships: []
      }
      exercises: {
        Row: {
          id: string
          tenant_id: string
          name: string
          description: string | null
          muscle_group: string | null
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          name: string
          description?: string | null
          muscle_group?: string | null
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          name?: string
          description?: string | null
          muscle_group?: string | null
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Relationships: []
      }
      workouts: {
        Row: {
          id: string
          tenant_id: string
          member_id: string
          created_by: string
          name: string
          notes: string | null
          date: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          member_id: string
          created_by: string
          name: string
          notes?: string | null
          date: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          member_id?: string
          created_by?: string
          name?: string
          notes?: string | null
          date?: string
          created_at?: string
          updated_at?: string
        }
        Relationships: []
      }
      workout_exercises: {
        Row: {
          id: string
          workout_id: string
          exercise_id: string
          sets: number
          reps: number
          weight: number | null
          notes: string | null
          order_index: number
          created_at: string
        }
        Insert: {
          id?: string
          workout_id: string
          exercise_id: string
          sets: number
          reps: number
          weight?: number | null
          notes?: string | null
          order_index: number
          created_at?: string
        }
        Update: {
          id?: string
          workout_id?: string
          exercise_id?: string
          sets?: number
          reps?: number
          weight?: number | null
          notes?: string | null
          order_index?: number
          created_at?: string
        }
        Relationships: []
      }
      diet_plans: {
        Row: {
          id: string
          tenant_id: string
          member_id: string
          created_by: string
          name: string
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          member_id: string
          created_by: string
          name: string
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          member_id?: string
          created_by?: string
          name?: string
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Relationships: []
      }
      diet_plan_meals: {
        Row: {
          id: string
          diet_plan_id: string
          meal_name: string
          description: string | null
          calories: number | null
          protein: number | null
          carbs: number | null
          fats: number | null
          meal_time: 'breakfast' | 'lunch' | 'dinner' | 'snack'
          order_index: number
          created_at: string
        }
        Insert: {
          id?: string
          diet_plan_id: string
          meal_name: string
          description?: string | null
          calories?: number | null
          protein?: number | null
          carbs?: number | null
          fats?: number | null
          meal_time: 'breakfast' | 'lunch' | 'dinner' | 'snack'
          order_index: number
          created_at?: string
        }
        Update: {
          id?: string
          diet_plan_id?: string
          meal_name?: string
          description?: string | null
          calories?: number | null
          protein?: number | null
          carbs?: number | null
          fats?: number | null
          meal_time?: 'breakfast' | 'lunch' | 'dinner' | 'snack'
          order_index?: number
          created_at?: string
        }
        Relationships: []
      }
      progress_photos: {
        Row: {
          id: string
          tenant_id: string
          member_id: string
          file_path: string
          taken_at: string
          notes: string | null
          created_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          member_id: string
          file_path: string
          taken_at: string
          notes?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          member_id?: string
          file_path?: string
          taken_at?: string
          notes?: string | null
          created_at?: string
        }
        Relationships: []
      }
      member_qr_codes: {
        Row: {
          id: string
          member_id: string
          qr_hash: string
          created_at: string
        }
        Insert: {
          id?: string
          member_id: string
          qr_hash: string
          created_at?: string
        }
        Update: {
          id?: string
          member_id?: string
          qr_hash?: string
          created_at?: string
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          id: string
          tenant_id: string
          user_id: string | null
          action: string
          table_name: string | null
          record_id: string | null
          old_data: Json | null
          new_data: Json | null
          ip_address: string | null
          created_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          user_id?: string | null
          action: string
          table_name?: string | null
          record_id?: string | null
          old_data?: Json | null
          new_data?: Json | null
          ip_address?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          user_id?: string | null
          action?: string
          table_name?: string | null
          record_id?: string | null
          old_data?: Json | null
          new_data?: Json | null
          ip_address?: string | null
          created_at?: string
        }
        Relationships: []
      }
      subscription_events: {
        Row: {
          id: string
          tenant_id: string
          event_type: string
          payload: Json
          created_at: string
        }
        Insert: {
          id?: string
          tenant_id: string
          event_type: string
          payload: Json
          created_at?: string
        }
        Update: {
          id?: string
          tenant_id?: string
          event_type?: string
          payload?: Json
          created_at?: string
        }
        Relationships: []
      }
    }
    Views: Record<string, never>
    Functions: Record<string, never>
    Enums: Record<string, never>
    CompositeTypes: Record<string, never>
  }
}

export type Tables<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Row']
export type Enums<T extends keyof Database['public']['Enums']> =
  Database['public']['Enums'][T]
