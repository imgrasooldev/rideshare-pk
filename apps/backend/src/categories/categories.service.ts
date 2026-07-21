import { Injectable } from "@nestjs/common";

/**
 * The marketplace category catalog. Each category maps to a ride `vertical`
 * (used as the search filter). `active` categories are searchable today;
 * `comingSoon` ones render in the grid but route to a waitlist. Kept as a
 * static catalog (not a table) — it's product taxonomy, versioned in code.
 */
export interface Category {
  key: string; // maps to rides.vertical
  label: string;
  tagline: string;
  icon: string; // symbolic name the app maps to an IconData
  active: boolean;
  comingSoon: boolean;
  sort: number;
}

const CATALOG: Category[] = [
  { key: "office", label: "Office Commute", tagline: "Daily ride to work", icon: "briefcase", active: true, comingSoon: false, sort: 1 },
  { key: "city", label: "Intercity", tagline: "Between cities", icon: "road", active: true, comingSoon: false, sort: 2 },
  { key: "school", label: "School Van", tagline: "Safe school pickup", icon: "school", active: true, comingSoon: false, sort: 3 },
  { key: "ladies", label: "Ladies Only", tagline: "Women-only rides", icon: "female", active: true, comingSoon: false, sort: 4 },
  { key: "airport", label: "Airport", tagline: "To & from the airport", icon: "flight", active: true, comingSoon: false, sort: 5 },
  { key: "corporate", label: "Corporate", tagline: "Company fleets", icon: "business", active: true, comingSoon: false, sort: 6 },
  { key: "events", label: "Events", tagline: "Weddings & occasions", icon: "celebration", active: true, comingSoon: false, sort: 7 },
  { key: "rentacar", label: "Rent a Car", tagline: "With or without driver", icon: "car_rental", active: false, comingSoon: true, sort: 8 },
  { key: "parcel", label: "Parcel", tagline: "Send packages", icon: "package", active: false, comingSoon: true, sort: 9 }
];

@Injectable()
export class CategoriesService {
  list(): Category[] {
    return [...CATALOG].sort((a, b) => a.sort - b.sort);
  }
}
