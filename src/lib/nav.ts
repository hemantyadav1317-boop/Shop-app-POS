import {
  BarChart3,
  BookOpen,
  ClipboardList,
  FileText,
  MoreHorizontal,
  Package,
  Receipt,
  Settings,
  ShoppingBag,
  Truck,
  Users,
  Wallet,
} from "lucide-react";

export type NavItem = { to: string; label: string; icon: typeof ShoppingBag };

export const PRIMARY_NAV: NavItem[] = [
  { to: "/pos", label: "New Sale", icon: ShoppingBag },
  { to: "/bills", label: "Bill History", icon: FileText },
  { to: "/saved", label: "Saved Orders", icon: ClipboardList },
  { to: "/inventory", label: "Inventory / Stock", icon: Package },
  { to: "/purchases", label: "Purchases", icon: Receipt },
  { to: "/customers", label: "Customers", icon: Users },
  { to: "/vendors", label: "Vendors", icon: Truck },
  { to: "/expenses", label: "Expenses", icon: Wallet },
  { to: "/daybook", label: "DayBook", icon: BookOpen },
  { to: "/reports", label: "Reports", icon: BarChart3 },
  { to: "/settings", label: "Settings", icon: Settings },
];

export const BOTTOM_NAV: NavItem[] = [
  { to: "/pos", label: "POS", icon: ShoppingBag },
  { to: "/bills", label: "Bills", icon: FileText },
  { to: "/inventory", label: "Stock", icon: Package },
  { to: "/customers", label: "Customers", icon: Users },
  { to: "/more", label: "More", icon: MoreHorizontal },
];
