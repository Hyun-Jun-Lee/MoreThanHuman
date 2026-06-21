---
name: Convia Interface System
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1b1b1b'
  on-surface-variant: '#4c4546'
  inverse-surface: '#303030'
  inverse-on-surface: '#f1f1f1'
  outline: '#7e7576'
  outline-variant: '#cfc4c5'
  surface-tint: '#5e5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1b1b1b'
  on-primary-container: '#848484'
  inverse-primary: '#c6c6c6'
  secondary: '#5d5f5f'
  on-secondary: '#ffffff'
  secondary-container: '#dfe0e0'
  on-secondary-container: '#616363'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#1b1b1b'
  on-tertiary-container: '#848484'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2e2e2'
  primary-fixed-dim: '#c6c6c6'
  on-primary-fixed: '#1b1b1b'
  on-primary-fixed-variant: '#474747'
  secondary-fixed: '#e2e2e2'
  secondary-fixed-dim: '#c6c6c7'
  on-secondary-fixed: '#1a1c1c'
  on-secondary-fixed-variant: '#454747'
  tertiary-fixed: '#e2e2e2'
  tertiary-fixed-dim: '#c6c6c6'
  on-tertiary-fixed: '#1b1b1b'
  on-tertiary-fixed-variant: '#474747'
  background: '#f9f9f9'
  on-background: '#1b1b1b'
  surface-variant: '#e2e2e2'
typography:
  display-xl:
    fontFamily: Inter
    fontSize: 80px
    fontWeight: '800'
    lineHeight: '0.9'
    letterSpacing: -0.04em
  display-xl-mobile:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.0'
    letterSpacing: -0.03em
  display-lg:
    fontFamily: Inter
    fontSize: 56px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: '0'
  body-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: '0'
  caption-mono:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 0.1em
  label-mono:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.0'
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  section-gap: 96px
  container-padding: 32px
  stack-lg: 48px
  stack-md: 24px
  stack-sm: 12px
  gutter: 24px
---

## Brand & Style

The design system is built on a high-contrast, editorial foundation that balances Swiss-style minimalism with a vibrant, block-based structural logic. It targets a sophisticated, tech-forward audience that values clarity and architectural precision.

The style is defined by **Flat Minimalism** with a **Structural Color-Block** approach. It rejects skeuomorphism, shadows, and gradients in favor of pure geometry, heavy linework, and saturated pastel surfaces. The emotional response is one of organized energy—systematic yet expressive. Hierarchy is established through extreme shifts in scale and the juxtaposition of dense black elements against airy, colorful backgrounds.

## Colors

The palette is anchored by a strict monochrome core. Black (#000000) is used for all primary text, borders, and functional elements, while White (#FFFFFF) serves as the primary canvas.

Functional depth is provided by a suite of "Block Colors." These are used as background fills for full-width sections or large cards to differentiate content zones.
- **Lime & Coral**: Used for high-energy calls to action or primary feature highlights.
- **Lilac & Mint**: Used for secondary features or informational clusters.
- **Cream**: The default alternative to pure white for a softer, editorial feel.
- **Navy**: Used exclusively for high-contrast footer sections or "Dark Mode" interruptions within a light flow, typically paired with white or lime text.

## Typography

This design system utilizes a dual-font strategy to balance impact with technical precision.

**Inter** is the workhorse for all prosetext and headlines. Display styles must be set with "Extra Bold" or "Black" weights and tight negative tracking to create a "wall of text" impact. 

**JetBrains Mono** is used for taxonomy, captions, and UI labels. It should always be set in all-caps with generous letter spacing to provide a technical, "meta-data" contrast to the organic shapes of the headlines.

For mobile, display sizes scale down aggressively while maintaining their tight leading to preserve the signature "stacked" look.

## Layout & Spacing

The layout follows a **Fixed-Fluid Hybrid Grid**. Content is housed within a 12-column grid system with a maximum width of 1440px. 

**Vertical Rhythm**: 
- A standard 96px gap is enforced between major sections to ensure significant "breath" between different color blocks.
- Internal component spacing follows an 8px base unit.

**Adaptivity**:
- **Desktop**: 12 columns, 24px gutters, 96px section gaps.
- **Tablet**: 8 columns, 20px gutters, 64px section gaps.
- **Mobile**: 4 columns, 16px gutters, 48px section gaps. Content should reflow vertically, and full-width color blocks should bleed to the edge of the viewport.

## Elevation & Depth

This design system uses **Zero Elevation**. There are no box-shadows, blurs, or layer offsets.

Depth is communicated through **Chromatic Layering** and **Border Weight**:
- **Level 0 (Base)**: White or Cream background.
- **Level 1 (Sections/Cards)**: Solid pastel color blocks.
- **Level 2 (Interactive)**: High-contrast black elements (buttons/inputs) that sit "on top" of color blocks.

Visual separation is achieved via 1px or 2px solid black strokes. When an element is focused or active, it does not lift; it changes its fill color or border weight.

## Shapes

The shape language is a mix of geometric "container" logic and organic "interactive" logic.

- **Primary Containers**: Large cards, feature blocks, and section containers use a **24px (rounded-lg)** corner radius.
- **Interactive Elements**: Buttons and tags are strictly **Pill-shaped (rounded-full)**. 
- **Form Inputs**: Use a slightly softer **12px radius** to distinguish them from the larger structural blocks.

This contrast between the "sturdy" 24px blocks and the "fluid" pill buttons helps users quickly identify touchpoints.

## Components

### Buttons
- **Primary**: Black fill with White text. Pill-shaped. Typography: `label-mono`. No shadow. On hover, background shifts to a specific Block Color (e.g., Lime).
- **Secondary**: Transparent fill with 2px Black border. Pill-shaped. 

### Cards
- **Feature Cards**: 24px corner radius. Solid fill from the Block Color palette. Headlines inside use `headline-md`.
- **Outline Cards**: 1px Black border with White background for lower-priority information.

### Inputs
- **Text Fields**: White background with 1px Black border. 12px radius. Placeholder text in `body-sm` with 50% opacity.
- **Focus State**: Border weight increases to 2px. No glow.

### Chips/Tags
- Small pill shapes. Always uses `caption-mono` typography. Backgrounds are typically secondary block colors or white to contrast against the parent container.

### Lists
- Separated by 1px horizontal Black rules. No bullets; use `caption-mono` labels for numbering to maintain the technical aesthetic.