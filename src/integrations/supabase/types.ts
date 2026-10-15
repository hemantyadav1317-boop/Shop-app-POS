export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.17"
  }
  public: {
    Tables: {
      customers: {
        Row: {
          address: string | null
          balance: number
          created_at: string
          id: string
          name: string
          phone: string | null
          shop_id: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          balance?: number
          created_at?: string
          id?: string
          name: string
          phone?: string | null
          shop_id: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          balance?: number
          created_at?: string
          id?: string
          name?: string
          phone?: string | null
          shop_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customers_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      expenses: {
        Row: {
          amount: number
          category: string
          created_at: string
          created_by: string | null
          id: string
          note: string | null
          shop_id: string
          spent_on: string
        }
        Insert: {
          amount?: number
          category?: string
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          shop_id: string
          spent_on?: string
        }
        Update: {
          amount?: number
          category?: string
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          shop_id?: string
          spent_on?: string
        }
        Relationships: [
          {
            foreignKeyName: "expenses_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          customer_id: string | null
          id: string
          mode: Database["public"]["Enums"]["payment_mode"]
          note: string | null
          sale_id: string | null
          shop_id: string
        }
        Insert: {
          amount?: number
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          id?: string
          mode?: Database["public"]["Enums"]["payment_mode"]
          note?: string | null
          sale_id?: string | null
          shop_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          id?: string
          mode?: Database["public"]["Enums"]["payment_mode"]
          note?: string | null
          sale_id?: string | null
          shop_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_sale_id_fkey"
            columns: ["sale_id"]
            isOneToOne: false
            referencedRelation: "sales"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          category: string
          cost_price: number
          created_at: string
          id: string
          is_active: boolean
          low_stock_at: number
          name: string
          price: number
          shop_id: string
          stock: number
          unit: Database["public"]["Enums"]["unit_type"]
          updated_at: string
        }
        Insert: {
          category?: string
          cost_price?: number
          created_at?: string
          id?: string
          is_active?: boolean
          low_stock_at?: number
          name: string
          price?: number
          shop_id: string
          stock?: number
          unit?: Database["public"]["Enums"]["unit_type"]
          updated_at?: string
        }
        Update: {
          category?: string
          cost_price?: number
          created_at?: string
          id?: string
          is_active?: boolean
          low_stock_at?: number
          name?: string
          price?: number
          shop_id?: string
          stock?: number
          unit?: Database["public"]["Enums"]["unit_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "products_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          email: string | null
          full_name: string | null
          id: string
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      purchase_items: {
        Row: {
          cost: number
          created_at: string
          id: string
          line_total: number
          name: string
          product_id: string | null
          purchase_id: string
          qty: number
          shop_id: string
        }
        Insert: {
          cost?: number
          created_at?: string
          id?: string
          line_total?: number
          name: string
          product_id?: string | null
          purchase_id: string
          qty?: number
          shop_id: string
        }
        Update: {
          cost?: number
          created_at?: string
          id?: string
          line_total?: number
          name?: string
          product_id?: string | null
          purchase_id?: string
          qty?: number
          shop_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_items_purchase_id_fkey"
            columns: ["purchase_id"]
            isOneToOne: false
            referencedRelation: "purchases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_items_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      purchases: {
        Row: {
          created_at: string
          created_by: string | null
          due: number
          id: string
          note: string | null
          paid: number
          shop_id: string
          total: number
          vendor_id: string | null
          vendor_name: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          due?: number
          id?: string
          note?: string | null
          paid?: number
          shop_id: string
          total?: number
          vendor_id?: string | null
          vendor_name?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          due?: number
          id?: string
          note?: string | null
          paid?: number
          shop_id?: string
          total?: number
          vendor_id?: string | null
          vendor_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "purchases_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchases_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      sale_items: {
        Row: {
          created_at: string
          id: string
          line_total: number
          name: string
          price: number
          product_id: string | null
          qty: number
          sale_id: string
          shop_id: string
          unit: Database["public"]["Enums"]["unit_type"]
        }
        Insert: {
          created_at?: string
          id?: string
          line_total?: number
          name: string
          price?: number
          product_id?: string | null
          qty?: number
          sale_id: string
          shop_id: string
          unit?: Database["public"]["Enums"]["unit_type"]
        }
        Update: {
          created_at?: string
          id?: string
          line_total?: number
          name?: string
          price?: number
          product_id?: string | null
          qty?: number
          sale_id?: string
          shop_id?: string
          unit?: Database["public"]["Enums"]["unit_type"]
        }
        Relationships: [
          {
            foreignKeyName: "sale_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sale_items_sale_id_fkey"
            columns: ["sale_id"]
            isOneToOne: false
            referencedRelation: "sales"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sale_items_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      sales: {
        Row: {
          bill_no: number
          created_at: string
          created_by: string | null
          customer_id: string | null
          customer_name: string | null
          customer_phone: string | null
          discount: number
          due: number
          id: string
          note: string | null
          paid: number
          payment_mode: Database["public"]["Enums"]["payment_mode"]
          shop_id: string
          sub_total: number
          tax: number
          total: number
        }
        Insert: {
          bill_no: number
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          customer_name?: string | null
          customer_phone?: string | null
          discount?: number
          due?: number
          id?: string
          note?: string | null
          paid?: number
          payment_mode?: Database["public"]["Enums"]["payment_mode"]
          shop_id: string
          sub_total?: number
          tax?: number
          total?: number
        }
        Update: {
          bill_no?: number
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          customer_name?: string | null
          customer_phone?: string | null
          discount?: number
          due?: number
          id?: string
          note?: string | null
          paid?: number
          payment_mode?: Database["public"]["Enums"]["payment_mode"]
          shop_id?: string
          sub_total?: number
          tax?: number
          total?: number
        }
        Relationships: [
          {
            foreignKeyName: "sales_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sales_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_orders: {
        Row: {
          created_at: string
          created_by: string | null
          customer_name: string | null
          customer_phone: string | null
          id: string
          label: string | null
          lines: Json
          shop_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          customer_name?: string | null
          customer_phone?: string | null
          id?: string
          label?: string | null
          lines?: Json
          shop_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          customer_name?: string | null
          customer_phone?: string | null
          id?: string
          label?: string | null
          lines?: Json
          shop_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_orders_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_members: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["shop_role"]
          shop_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["shop_role"]
          shop_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["shop_role"]
          shop_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_members_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      shops: {
        Row: {
          address: string | null
          bill_prefix: string
          created_at: string
          currency: string
          gst_number: string | null
          id: string
          name: string
          owner_id: string
          phone: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          bill_prefix?: string
          created_at?: string
          currency?: string
          gst_number?: string | null
          id?: string
          name: string
          owner_id: string
          phone?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          bill_prefix?: string
          created_at?: string
          currency?: string
          gst_number?: string | null
          id?: string
          name?: string
          owner_id?: string
          phone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      stock_movements: {
        Row: {
          change: number
          created_at: string
          id: string
          note: string | null
          product_id: string | null
          reason: Database["public"]["Enums"]["stock_reason"]
          ref_id: string | null
          shop_id: string
        }
        Insert: {
          change?: number
          created_at?: string
          id?: string
          note?: string | null
          product_id?: string | null
          reason?: Database["public"]["Enums"]["stock_reason"]
          ref_id?: string | null
          shop_id: string
        }
        Update: {
          change?: number
          created_at?: string
          id?: string
          note?: string | null
          product_id?: string | null
          reason?: Database["public"]["Enums"]["stock_reason"]
          ref_id?: string | null
          shop_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      vendors: {
        Row: {
          address: string | null
          created_at: string
          id: string
          name: string
          payable: number
          phone: string | null
          shop_id: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          id?: string
          name: string
          payable?: number
          phone?: string | null
          shop_id: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          id?: string
          name?: string
          payable?: number
          phone?: string | null
          shop_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "vendors_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      collect_due: {
        Args: {
          _amount: number
          _customer_id: string
          _mode: Database["public"]["Enums"]["payment_mode"]
          _shop_id: string
        }
        Returns: undefined
      }
      create_purchase: {
        Args: {
          _items: Json
          _note: string
          _paid: number
          _shop_id: string
          _vendor_id: string
          _vendor_name: string
        }
        Returns: string
      }
      create_sale: {
        Args: {
          _customer_id: string
          _customer_name: string
          _customer_phone: string
          _discount: number
          _items: Json
          _note: string
          _paid: number
          _payment_mode: Database["public"]["Enums"]["payment_mode"]
          _shop_id: string
        }
        Returns: string
      }
      has_shop_role: {
        Args: {
          _roles: Database["public"]["Enums"]["shop_role"][]
          _shop_id: string
        }
        Returns: boolean
      }
      is_shop_member: { Args: { _shop_id: string }; Returns: boolean }
      is_shop_owner: { Args: { _shop_id: string }; Returns: boolean }
    }
    Enums: {
      payment_mode: "cash" | "online" | "credit" | "split" | "set_later"
      shop_role: "owner" | "manager" | "cashier"
      stock_reason: "sale" | "purchase" | "adjustment" | "return" | "opening"
      unit_type: "kg" | "pc"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      payment_mode: ["cash", "online", "credit", "split", "set_later"],
      shop_role: ["owner", "manager", "cashier"],
      stock_reason: ["sale", "purchase", "adjustment", "return", "opening"],
      unit_type: ["kg", "pc"],
    },
  },
} as const
