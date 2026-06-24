---
version: alpha
name: Microsoft Fluent UI React v9
description: Design system spec for building Microsoft 365-grade enterprise interfaces with Fluent UI React v9, driven by tokens, accessible by default, and component-native.
colors:
  colorNeutralForeground1: "#242424"
  colorNeutralForeground2: "#424242"
  colorNeutralForeground3: "#616161"
  colorNeutralForegroundDisabled: "#bdbdbd"
  colorNeutralBackground1: "#ffffff"
  colorNeutralBackground2: "#fafafa"
  colorNeutralBackground3: "#f5f5f5"
  colorNeutralStroke1: "#d1d1d1"
  colorBrandBackground: "#0f6cbd"
  colorBrandForeground1: "#0f6cbd"
  colorBrandForegroundLink: "#115ea3"
  colorStatusDangerForeground1: "#bc2f32"
  colorStatusSuccessForeground1: "#0e700e"
  colorStatusWarningForeground1: "#bd6500"
typography:
  caption2:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 10px
    fontWeight: 400
    lineHeight: 14px
  caption1:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 12px
    fontWeight: 400
    lineHeight: 16px
  body1:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 14px
    fontWeight: 400
    lineHeight: 20px
  body2:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 16px
    fontWeight: 400
    lineHeight: 22px
  subtitle2:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 16px
    fontWeight: 600
    lineHeight: 22px
  subtitle1:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 20px
    fontWeight: 600
    lineHeight: 28px
  title3:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 24px
    fontWeight: 600
    lineHeight: 32px
  title2:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 28px
    fontWeight: 600
    lineHeight: 36px
  title1:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 32px
    fontWeight: 600
    lineHeight: 40px
  largeTitle:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 40px
    fontWeight: 600
    lineHeight: 52px
  display:
    fontFamily: '"Segoe UI", "Segoe UI Web (West European)", -apple-system, BlinkMacSystemFont, Roboto, "Helvetica Neue", sans-serif'
    fontSize: 68px
    fontWeight: 600
    lineHeight: 92px
rounded:
  none: 0
  small: 2px
  medium: 4px
  large: 6px
  xlarge: 8px
  circular: 10000px
spacing:
  xxs: 2px
  xs: 4px
  snudge: 6px
  s: 8px
  mnudge: 10px
  m: 12px
  l: 16px
  xl: 20px
  xxl: 24px
  xxxl: 32px
components:
  button-primary:
    backgroundColor: "{colors.colorBrandBackground}"
    textColor: "#ffffff"
    typography: "{typography.body1}"
    rounded: "{rounded.medium}"
    padding: 0 12px
    height: 32px
  button-secondary:
    backgroundColor: "{colors.colorNeutralBackground1}"
    textColor: "{colors.colorNeutralForeground1}"
    typography: "{typography.body1}"
    rounded: "{rounded.medium}"
    padding: 0 12px
    height: 32px
  card:
    backgroundColor: "{colors.colorNeutralBackground1}"
    textColor: "{colors.colorNeutralForeground1}"
    rounded: "{rounded.xlarge}"
    padding: "{spacing.m}"
  input:
    backgroundColor: "{colors.colorNeutralBackground1}"
    textColor: "{colors.colorNeutralForeground1}"
    typography: "{typography.body1}"
    rounded: "{rounded.medium}"
    height: 32px
  dialog-surface:
    backgroundColor: "{colors.colorNeutralBackground1}"
    textColor: "{colors.colorNeutralForeground1}"
    rounded: "{rounded.xlarge}"
    padding: "{spacing.xxl}"
---

# Microsoft Fluent UI React v9 DESIGN.md

Generated for AI coding agents and product teams that must build interfaces consistent with Microsoft Fluent UI React v9.

Last researched: 2026-06-20  
Primary source: Fluent UI React v9 Storybook, reported version v9.74.1

This document is based on the official Fluent UI React v9 Storybook under:

- https://storybooks.fluentui.dev/react/?path=/docs/concepts-introduction--docs
- https://storybooks.fluentui.dev/react/?path=/docs/concepts-developer-theming--docs
- https://storybooks.fluentui.dev/react/?path=/docs/concepts-developer-styling-components--docs
- https://storybooks.fluentui.dev/react/?path=/docs/concepts-developer-accessibility-experiences--docs
- https://storybooks.fluentui.dev/react/?path=/docs/concepts-developer-accessibility-component-labelling--docs
- https://storybooks.fluentui.dev/react/?path=/docs/concepts-developer-positioning-components--docs
- https://storybooks.fluentui.dev/react/?path=/docs/theme-colors--docs
- https://storybooks.fluentui.dev/react/?path=/docs/theme-typography--docs
- https://storybooks.fluentui.dev/react/?path=/docs/theme-spacing--docs
- https://storybooks.fluentui.dev/react/?path=/docs/theme-border-radii--docs
- https://storybooks.fluentui.dev/react/?path=/docs/theme-shadows--docs
- Component docs for Button, Card, Field, Input, Textarea, Checkbox, Combobox, Dropdown, Dialog, Drawer, Menu, Popover, Tooltip, MessageBar, Toast, Table, DataGrid, TabList, Toolbar, Skeleton, Spinner, and FluentProvider.

## Overview

Fluent UI React v9 is a pragmatic enterprise product system. It prioritizes cohesion, accessibility, performance, predictable interaction, and design-to-code fidelity through tokens. The resulting UI should feel like Microsoft 365: calm, dense enough for work, carefully aligned, accessible by default, and restrained in visual expression.

Build interfaces that are:

- Clear before expressive.
- Token-driven before custom-styled.
- Component-native before hand-rolled.
- Keyboard and screen-reader complete before visually polished.
- Efficient for repeated professional workflows.

Do not turn Fluent UI into a decorative marketing system. Avoid oversized hero treatments, ornamental gradients, arbitrary rounded cards, and custom controls when a Fluent component already exists.

### Engineering Foundation

Use `@fluentui/react-components` as the primary import surface. Wrap the app or feature root in `FluentProvider`, style with `makeStyles`, merge classes with `mergeClasses`, and read every value from `tokens` rather than referencing Fluent CSS variables directly.

```tsx
import {
  FluentProvider,
  webLightTheme,
  makeStyles,
  mergeClasses,
  tokens,
  Button,
  Field,
  Input,
} from "@fluentui/react-components";

const useStyles = makeStyles({
  root: {
    backgroundColor: tokens.colorNeutralBackground1,
    color: tokens.colorNeutralForeground1,
    padding: tokens.spacingVerticalL,
    borderRadius: tokens.borderRadiusMedium,
  },
});

export function AppRoot() {
  return (
    <FluentProvider theme={webLightTheme}>
      <MainExperience />
    </FluentProvider>
  );
}
```

When adding local style variants:

```tsx
const useStyles = makeStyles({
  base: {
    display: "flex",
    gap: tokens.spacingHorizontalM,
  },
  selected: {
    backgroundColor: tokens.colorNeutralBackground1Selected,
  },
});

function Row({ selected, className }: { selected?: boolean; className?: string }) {
  const styles = useStyles();
  return (
    <div
      className={mergeClasses(
        styles.base,
        selected && styles.selected,
        className
      )}
    />
  );
}
```

### Theme System

Fluent themes are flat token maps. Component styles remain stable across themes; theme switching changes token values via CSS variables set by `FluentProvider`.

Use one of:

- `webLightTheme`
- `webDarkTheme`
- `teamsLightTheme`
- `teamsDarkTheme`
- `teamsHighContrastTheme`, only for legacy apps that explicitly require it

For standard high contrast support, rely on Windows High Contrast / forced colors behavior supported by Fluent components. Do not choose a hardcoded high contrast theme as the normal accessibility strategy.

For brand customization, derive a theme from a brand color ramp with the Fluent factory functions such as `createLightTheme()` or `createDarkTheme()`. Override existing tokens only with design approval. Extending tokens is allowed, but be conservative because extra tokens become extra CSS variables.

## Colors

Use semantic tokens rather than literal colors.

Recommended roles:

- Primary text: `tokens.colorNeutralForeground1`
- Secondary text: `tokens.colorNeutralForeground2`
- Tertiary/meta text: `tokens.colorNeutralForeground3`
- Page surface: `tokens.colorNeutralBackground1`
- Subtle surface: `tokens.colorNeutralBackground2`
- Card or raised surface: component defaults first, then `colorNeutralBackground*` tokens
- Brand action: `tokens.colorBrandBackground`, `tokens.colorBrandForeground1`
- Destructive/error: component `intent="error"` or validation state before custom red tokens

Do not invent local blue, gray, red, or green ramps. If a color is not represented by a Fluent token, treat that as a design-system exception.

Do not use color alone to communicate state; pair color with text, icon, or shape.

## Typography

Use Fluent typography styles and Text components. Default family is Segoe UI with platform fallbacks.

Common scale:

- `caption2`: 10/14
- `caption1`: 12/16
- `body1`: 14/20, default product copy
- `body2`: 16/22
- `subtitle2`: 16/22 semibold
- `subtitle1`: 20/28 semibold
- `title3`: 24/32 semibold
- `title2`: 28/36 semibold
- `title1`: 32/40 semibold
- `largeTitle`: 40/52 semibold
- `display`: 68/92 semibold, rare and usually unsuitable for dense enterprise apps

Use `typographyStyles` when building custom layout text:

```tsx
const useStyles = makeStyles({
  title: {
    ...typographyStyles.subtitle1,
    color: tokens.colorNeutralForeground1,
  },
  meta: {
    ...typographyStyles.caption1,
    color: tokens.colorNeutralForeground3,
  },
});
```

Keep enterprise screens mostly in `body1`, `caption1`, `subtitle2`, and `subtitle1`. Use `title*` for page or panel headings, not for repeated cards.

## Layout

Use quiet, functional layouts:

- Align content to predictable grids.
- Keep dense operational screens scan-friendly.
- Prefer full-width page bands or plain constrained layouts over nested cards.
- Use cards only for repeated objects or truly grouped content.
- Do not put cards inside cards.
- Avoid single-column tables; use List, Card, or structured rows instead.
- Give tables and grids a `min-width` for high zoom and small viewport behavior.
- Ensure text does not overlap, truncate unpredictably, or resize containers during interaction.

### Spacing Scale

Use the Fluent spacing scale:

- `XXS`: 2px
- `XS`: 4px
- `SNudge`: 6px
- `S`: 8px
- `MNudge`: 10px
- `M`: 12px
- `L`: 16px
- `XL`: 20px
- `XXL`: 24px
- `XXXL`: 32px

Use horizontal and vertical variants:

- `tokens.spacingHorizontalM`
- `tokens.spacingVerticalL`

Default patterns:

- Inline icon/text gap: `XS` to `S`
- Field stack gap: `S` to `M`
- Toolbar item gap: `XS` to `S`
- Section internal padding: `L` to `XXL`
- Page gutters: `XXL` to `XXXL`, responsive
- Dense table/cell padding: prefer component size props before custom spacing

### Button Alignment

- Dialogs and panels: actions right-aligned.
- Single-page forms and focused tasks: actions left-aligned.
- Primary action goes before secondary action.
- Use only one primary button in a local action set.

### Positioning

Fluent positioned components share the `positioning` prop.

Common options:

- `position`: `above`, `below`, `before`, `after`
- `align`: `start`, `center`, `end`, `top`, `bottom`
- `autoSize`: keep popup within available viewport space
- `fallbackPositions`: explicit fallback placement list
- `offset`: controlled distance from trigger
- `matchTargetSize="width"`: align popup width to trigger
- `coverTarget`: overlay the trigger target
- `pinned`: disable automatic repositioning; use rarely

For menus, dropdowns, comboboxes, tooltips, and popovers, verify placement at:

- Small viewport
- 200% zoom
- Near page edges
- Scroll containers
- RTL layouts if supported

## Elevation & Depth

Use component defaults for elevation first. Elevation should communicate layering, not brand personality.

Shadow scale:

- `shadow2`, `shadow4`: low elevation
- `shadow8`, `shadow16`: floating surfaces and menus/popovers
- `shadow28`, `shadow64`: major overlays only

Do not use decorative shadows for visual drama.

## Shapes

Use component defaults for radius and stroke first.

Radius scale:

- `borderRadiusNone`: 0px
- `borderRadiusSmall`: 2px
- `borderRadiusMedium`: 4px
- `borderRadiusLarge`: 6px
- `borderRadiusXLarge`: 8px
- `borderRadiusCircular` only for avatars, pills, or fully circular controls

Fluent product UI should generally sit between 2px and 8px radius. Avoid arbitrary 16px+ card-heavy layouts unless the component or scenario calls for it.

Note: Fluent UI React v9 ships only the radius tokens listed above. There is no `borderRadius2XLarge` token; any larger radius must be an explicitly approved custom extension, not assumed to exist.

For stroke, prefer Fluent stroke tokens (for example `tokens.colorNeutralStroke1` and `tokens.strokeWidthThin`) and component borders rather than ad hoc border widths.

## Components

### Forms

Use `Field` for form labels, validation messages, and hints.

Do:

- Wrap one control per `Field`.
- Use `validationState="error" | "warning" | "success" | "none"`.
- Use `validationMessage` for actionable validation text.
- Use `hint` sparingly.
- Use Checkbox's own `label`; do not label a Checkbox through `Field`.
- Keep disabled labels readable; do not mark Field label disabled just because the child control is disabled.

Do not:

- Put multiple controls under one `Field` label.
- Use both `hint` and `validationMessage` unless the design explicitly requires both and the narration has been checked.
- Use placeholder as the label.

Selection controls:

- Use `Select` for simple single-select native/mobile-friendly cases.
- Use `Dropdown` when options require JSX/styled content.
- Use `Combobox` when users can type/filter or enter freeform values.
- Use Checkbox group for fewer than 10 simple multi-select options.
- Use multi-select Dropdown for 10+ options.
- Set `Option value` or `text` when option children are JSX, so type-to-find remains accessible.
- Prefer `inlinePopup={true}` for Dropdown/Combobox when possible for better VoiceOver behavior.

### Buttons And Commands

Use `Button` for actions, not navigation. Use `Link` for navigation, except wizard-style Back/Next.

Button appearances:

- `primary`: one main action in the local area
- `secondary`: default secondary action
- `outline`: lower emphasis with border
- `subtle`: blends into surface until hover/focus
- `transparent`: icon/tool actions and quiet surfaces

Content:

- Use sentence-style capitalization.
- Prefer concise verbs.
- Add a noun when the action could be ambiguous: "Delete folder", "Create account".
- Do not default focus to destructive actions.
- Keep custom-styled buttons at least 24px by 24px.

Use `disabledFocusable` only where a disabled command must remain in tab order, such as menu or command bar consistency. Avoid it for ordinary standalone buttons.

### Cards

Use `Card` for information and actions about a single concept or object, such as a file, app, document, person, or contact.

Guidance:

- Default card role is `group`.
- If the card is focusable, provide meaningful `aria-label` or `aria-labelledby` and `aria-describedby`.
- Use a proper heading element for larger cards with one clear title.
- Use card appearance consistently across the same object type.
- Choose `filled` for most cards.
- Use `filled-alternative` on light gray/white surfaces when contrast needs help.
- Use `outline` when a border is needed without filled background.
- Use `subtle` for lightweight interactive list-like cards.

Avoid card layouts for whole page sections. Cards are repeated objects, not a substitute for layout.

### Overlays And Layering

Use the lightest component that fits the task:

- `Tooltip`: short non-interactive information tied to a control.
- `InfoLabel`: tooltip-like help for static label/icon patterns.
- `Popover`: supplemental content or lightweight task UI.
- `Menu`: list of actions.
- `Dialog`: blocking decision or required information.
- `OverlayDrawer`: full-attention side panel.
- `InlineDrawer`: persistent side panel/navigation that preserves page interaction.

#### Tooltip

- Must wrap interactive controls.
- Must declare `relationship="label" | "description" | "inaccessible"`.
- Do not put interactive content in a Tooltip.
- Do not use Tooltip as the full-text alternative for truncated content.
- Use `InfoLabel` for static help icons.

Icon-only controls:

```tsx
<Tooltip content="Refresh" relationship="label">
  <Button icon={<ArrowClockwiseRegular />} />
</Tooltip>
```

#### Popover

- Use for non-essential information or lightweight interactions.
- If focusable elements exist inside, set `trapFocus`.
- If no interactive content exists, set `tabIndex={-1}` on `PopoverSurface`.
- Do not nest more than two Popover levels.
- Do not put large workflows in Popover; move them to page, Drawer, or Dialog.

#### Menu

- Use `MenuTrigger` as the first child.
- Use `MenuList` as the only child of `MenuPopover`.
- Use `MenuItemLink` for navigation items.
- Use `hasIcons` or `hasCheckmarks` to preserve alignment when only some items have those slots.
- Use `positioning={{ autoSize: true }}` for menus that may be clipped at high zoom or small viewports.
- Do not put focusable/clickable controls inside menu items.
- Do not exceed two nested menu levels.
- Do not mix checkbox and radio menu items without `MenuGroup`.

#### Dialog

Use Dialog sparingly when the user must make a decision before proceeding.

Required structure:

```tsx
<Dialog>
  <DialogTrigger disableButtonEnhancement>
    <Button>Open</Button>
  </DialogTrigger>
  <DialogSurface aria-describedby={undefined}>
    <DialogBody>
      <DialogTitle>Dialog title</DialogTitle>
      <DialogContent>Content</DialogContent>
      <DialogActions>
        <Button appearance="primary">Save</Button>
        <Button>Cancel</Button>
      </DialogActions>
    </DialogBody>
  </DialogSurface>
</Dialog>
```

Rules:

- Include title, content, actions, and body.
- Keep actions to three or fewer buttons.
- Validate inline before closing.
- Use modal dialogs only for critical choices or destructive/irreversible tasks.
- Do not open a Dialog from another Dialog.
- Do not use a Dialog with no focusable elements.
- If Dialog contains Menu, Combobox, Dropdown, or Popover, set `aria-modal={false}` on `DialogSurface` for VoiceOver access.
- For complex content, consider `aria-describedby={undefined}` instead of narrating the whole dialog content as one description.
- In SSR, keep `unmountOnClose={true}` unless there is a deliberate reason.

#### Drawer

- Use `OverlayDrawer` only when full attention is required.
- Use `InlineDrawer` for navigation or supplemental content that should coexist with the page.
- Use `Drawer` only when the component must switch between overlay and inline modes responsively.
- Restore focus to the trigger when a closeable drawer closes.
- For large page-level `InlineDrawer`, consider `role="region"` with a meaningful label.

### Feedback And Notifications

#### MessageBar

Use `MessageBar` for persistent information about the state of a page, surface, panel, dialog, or card.

Rules:

- Put MessageBars inside `MessageBarGroup`.
- Include dismiss as `containerAction` when appropriate.
- Use preset intents: `info`, `success`, `warning`, `error`.
- Keep content under roughly 100 characters.
- Use `shape="square"` for page-level messages and rounded for component-level messages.
- Avoid entry animations on page load.
- Do not customize announcement politeness without accessibility review.
- Configure `AriaLiveAnnouncer` high in the React tree for live announcements.

#### Toast

Use Toast for temporary, non-critical notifications.

Rules:

- Render one `Toaster` per app.
- Configure defaults on `Toaster`.
- Keep one consistent toast position.
- Limit how many toasts can appear.
- Provide a durable notification center or permanent surface for toast content.
- Use `politeness` intentionally; do not make every toast assertive.
- Provide a keyboard shortcut to actionable toasts when actions are present.

#### Loading

Use `Skeleton` when expected loading is longer than 1 second and layout shape is known.

- Keep skeletons simple: rectangles and circles.
- Match approximate content width.
- Set `aria-busy="true"` on the loading container.
- Use unique concise labels for multiple loading regions.
- Announce "loaded" once for a completed group, not for every item.

Use `Spinner` for tasks that are not immediate or when processing is underway.

- Use one spinner at a time.
- Pair with a short verb: "Saving", "Processing", "Updating".
- If the spinner is the only page element, set `tabIndex={0}`.
- Add a description when reduced motion is active.
- Do not show spinners for immediate tasks.

### Data Display

Use `DataGrid` for common feature-rich tabular data: sorting, selection, column sizing, and standard Microsoft accessibility patterns.

Use low-level `Table` only when the desired behavior is significantly custom or non-standard.

Rules for both:

- Always include a header row.
- Provide `aria-labelledby` when a visible heading labels the grid/table.
- Provide `aria-label` when no visible label exists.
- Set a `min-width` for high zoom and small screens.
- Do not use table/grid for single-column content.
- Do not override built-in roles.
- Once keyboard navigation is introduced, follow the ARIA grid pattern.
- Use `TableCellLayout` for cell media, main text, description, and truncation.

### Navigation And Organization

Use Fluent navigation components where available:

- `TabList` for switching related panels on the same page.
- `Toolbar` for dense command groups.
- `Breadcrumb` for hierarchical page location.
- `Nav` for app-level or section-level navigation.
- `MenuButton` for command menus.
- `SplitButton` only when a default action plus related alternatives are both necessary.

Keep command surfaces predictable:

- Icons align.
- Text labels are concise.
- Selection/checkmark slots are reserved consistently.
- Disabled commands remain understandable.
- Keyboard navigation is documented and testable.

### Motion

Use Fluent motion components or component motion slots when available. Motion should clarify change, not decorate.

Rules:

- Avoid page-load motion for persistent status UI.
- Respect reduced motion.
- Use enter/exit animation for transient surfaces only when it improves orientation.
- Keep overlay, toast, drawer, and popover motion consistent with Fluent defaults.
- Do not create bespoke easing/duration systems unless Fluent motion cannot cover the scenario.

### Component Decision Matrix

Use this when generating new UI:

| Need | Use | Avoid |
| --- | --- | --- |
| Primary command | `Button appearance="primary"` | Multiple primary buttons |
| Navigation | `Link`, `Breadcrumb`, `Nav` | Button as link |
| Simple text input | `Field` + `Input` | Bare input without label |
| Long text input | `Field` + `Textarea` | Multi-line `Input` hacks |
| Boolean setting | `Checkbox` or `Switch` | Dropdown with Yes/No |
| Few multi-select options | Checkbox group | Multi-select Dropdown |
| Many multi-select options | `Dropdown multiselect` | Long checkbox wall |
| Searchable/freeform selection | `Combobox` | Dropdown with manual filter |
| Simple native select | `Select` | Dropdown if no styled options |
| Action list | `Menu` | Popover full of buttons |
| Short help for control | `Tooltip` | Popover |
| Static label help | `InfoLabel` | Tooltip on static icon |
| Lightweight extra content | `Popover` | Dialog |
| Blocking confirmation | `Dialog` | Toast |
| Supplemental side workflow | `Drawer` | Dialog if page context matters |
| Persistent page status | `MessageBar` | Toast |
| Temporary status | `Toast` | MessageBar for ephemeral update |
| Known slow content load | `Skeleton` | Spinner for whole page skeleton |
| Unknown processing | `Spinner` | Skeleton with fake content detail |
| Standard data grid | `DataGrid` | Hand-rolled table |
| Highly custom tabular UI | `Table` primitives | DataGrid contortions |

## Do's and Don'ts

### Non-Negotiable Rules

1. Wrap the app or feature root in `FluentProvider` and pass an official or derived Fluent theme.
2. Use Fluent tokens for color, typography, spacing, radius, stroke, shadow, and motion-adjacent values.
3. Never reference Fluent theme CSS variables directly. Use `tokens`.
4. Style with `makeStyles` from `@fluentui/react-components`.
5. Merge classes with `mergeClasses`; do not concatenate Griffel classes manually.
6. Prefer Fluent components over raw HTML for controls, overlays, menus, form fields, selection, feedback, data display, and navigation.
7. Every interactive control must have a correct accessible name.
8. Do not encode role, state, position, or action hints redundantly in `aria-label`.
9. Preserve visible text as the source of accessible labels whenever possible.
10. Do not add focus to static text.
11. Do not use placeholder text as a label.
12. Do not use color alone to communicate state.
13. Test keyboard order, focus restoration, screen-reader labels, high contrast, zoom, and reduced motion.

### Accessibility Model

Design accessibility at the structure level, not as a patch at the end.

For every new screen, specify:

- Heading structure and landmarks.
- Tab order and arrow-key behavior.
- Labels for icon-only controls and unnamed containers.
- State-change announcements for errors, confirmations, async updates, and dynamic UI.
- Focus movement when UI appears or disappears.
- Focus trapping for dialogs, overlay drawers, and popovers with interactive content.
- High contrast and zoom/reflow behavior.
- Reduced motion behavior where animation communicates state.

Accessible names:

- Prefer visible text via native labels, `aria-labelledby`, or component label props.
- Do not add words like "button", "tab", "selected", "first of four", or "click here" to labels.
- Let semantic roles and ARIA states provide role, state, and position.
- For repeated items, label the group once instead of repeating the same phrase in every item.
- Use `aria-describedby` for supporting descriptions and validation messages.

Static text:

- Do not set `tabIndex={0}` on static text.
- Reference explanatory text with `aria-describedby`.
- Use `role="group"` with `aria-label` or `aria-labelledby` when grouping controls needs narration.

### Content Style

Use Microsoft-style product copy:

- Sentence-style capitalization.
- Direct verbs.
- Short labels.
- Specific nouns when needed.
- No "click here".
- No redundant role words in labels.
- Error messages explain what happened and how to fix it.
- Destructive actions name the object being affected.

Examples:

- Good: "Delete folder"
- Bad: "Click here to delete"
- Good: "Send message"
- Bad: "Send message button"
- Good: "Files"
- Bad: "Files tab is active"

### Code Review Checklist

Before shipping Fluent UI React v9 work, verify:

- The UI is inside `FluentProvider`.
- Official or derived theme is used.
- All colors, spacing, typography, radius, stroke, and shadow use tokens or component defaults.
- `makeStyles` is module-scoped.
- `mergeClasses` is used for class merging.
- No direct Fluent CSS variable names are referenced.
- No arbitrary hex values remain except external brand assets or approved exceptions.
- Every form control has a visible or programmatic label.
- Placeholder text is not the only label.
- Icon-only buttons have tooltip relationship or explicit accessible labels.
- Accessible names do not duplicate role, state, position, or action instructions.
- Static text is not focusable.
- Dialogs and drawers restore focus.
- Popovers with controls trap focus.
- Menus do not contain nested focusable controls.
- Dropdown/Combobox JSX options have text/value for type-to-find.
- MessageBar and Toast announcements are configured through app-level live announcer strategy.
- Loading states use `aria-busy`, concise labels, and limited announcements.
- Tables/DataGrids have labels, headers, min-width, and native roles preserved.
- High contrast, 200% zoom, keyboard-only navigation, and reduced motion are manually checked.

### Default Aesthetic

When no product-specific direction is given, choose:

- Theme: `webLightTheme`
- Background: neutral white/gray Fluent surfaces
- Text: neutral foreground tokens
- Accent: Fluent brand tokens
- Type: Segoe UI via Fluent typography
- Density: medium, with compact options for data-heavy screens
- Radius: 4px to 8px
- Shadow: minimal, only for actual elevation
- Layout: structured, aligned, and task-first
- Interaction: visible focus, clear hover/pressed/selected states, no surprise motion

The interface should feel like a serious Microsoft productivity surface: useful, orderly, accessible, and quietly refined.
