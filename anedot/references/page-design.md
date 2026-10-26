# Donation page design principles

Generic rules for beautiful, high-converting donation pages. Adapt them to each organization's own logo, colors and voice. Never invent stats, testimonials, logos or endorsements. If a real number or quote isn't available, leave it out.

## 0. The one rule
A donation page has one job: help someone who already wants to give finish the gift quickly and feel good about it. Remove anything that doesn't serve that.

## 1. Layout and hierarchy (top to bottom)
1. **Header:** the org's logo on the left (or centered), small, about 32 to 48px tall. No navigation menu, because every link is an exit.
2. **Hero:** an optional header image (see section 4), then the headline and one supporting line.
3. **The form:** the amount picker, the one-time/monthly toggle, the give button. On desktop it sits in the first screen. On mobile the headline and the first amounts should be visible without scrolling.
4. **Trust:** one or two real proof points near the button. For example: a secure-payment note, the tax-deductible status (only if true), a one-sentence "where your gift goes", or one real quote with a name.
5. **Footer:** legal name, contact, privacy and refund links. Small and quiet.
- One column on mobile. On desktop, either one centered column (about 560 to 640px for the form) or a story on the left with the form on the right. Never three columns.
- Generous white space. Fewer sections that are well spaced beat many boxes ("card soup").

## 2. Color and contrast
- Start from the org's brand. Choose **one background** (usually white or a very light tint of the brand color), **one ink** color for text (near-black or the darkest brand shade), and **one accent** used only for the give button and the selected state.
- The accent appears on the primary button and the selected amount, nowhere else. Secondary actions are outlined or plain text.
- Contrast must meet WCAG 2.2 AA: body text at least 4.5:1, large text (24px+, or 18.66px+ bold) at least 3:1, button text against the button fill at least 4.5:1, and borders or focus rings at least 3:1 against what's next to them. Check every pair, including the selected state and dark mode if there is one.
- Never put text over a busy photo. If text must sit on an image, use a solid or strongly darkened area behind it, then re-check contrast.
- Avoid: rainbow palettes, gradients on buttons, red for anything except errors, and more than one bright color competing with the button.

## 3. Typography
- At most two families: a display face for the headline (it can carry the brand's personality, serif or sans) and a highly readable sans for the body and form. One family in two weights is also fine. Every stack ends in a system-font fallback.
- Mobile sizes: headline 28 to 36px, supporting line 17 to 19px, body 16 to 18px, form labels 14 to 16px, amount buttons 18 to 20px semibold. Inputs at least 16px so iOS doesn't zoom.
- Line length 45 to 75 characters. Line height about 1.15 for headlines and 1.5 for body.
- Weights: headline 600 to 700, body 400, button 600. Sentence case everywhere. Avoid all-caps except tiny eyebrow labels with letter spacing.

## 4. Imagery
- A header image helps when it shows the mission's real subject (the people, place or work the gift supports), it's authentic (not stock-looking), and it has one clear focal point.
- Skip it, or use a solid or brand-tint band, when no good real photo exists. A weak image hurts more than none.
- Aspect ratio: about 3:1 to 4:1 on desktop (for example 1600x480) and about 16:9 or 4:3 on mobile, so the form isn't pushed off screen. Keep the focal point centered so both crops work.
- Don't put the logo, headline or paragraphs inside the image file. Real text goes in HTML for accessibility and sharp rendering. The logo lives in the header, not on the photo.
- Every meaningful image gets alt text. Decorative images get empty alt text.
- Compress images (WebP or AVIF, under about 200 KB for the hero), because slow pages lose gifts.

## 5. Suggested amounts
- 3 to 5 preset amounts plus an "Other" field. Four is a good default (a 2x2 grid on mobile).
- Order them from low to high. Preselect a middle-to-upper amount that fits the audience (often the second or third tier), not the lowest.
- Base the tiers on the org's real giving data when available. Otherwise use round numbers that step up clearly (for example 25 / 50 / 100 / 250 for one-time gifts).
- Monthly tiers are lower than one-time tiers (for example 10 / 20 / 35 / 50). Change the presets when the toggle changes.
- One-time vs. monthly: a clear two-option segmented toggle above the amounts. Default to one-time unless the org deliberately runs a monthly program. Encourage monthly with honest framing ("Give monthly to support year-round work"), never with a pre-checked box or a guilt modal.
- Optional impact labels under each amount ("$50 provides X") only when the org has a real, verifiable figure.
- The custom amount field shows the currency symbol, uses a numeric keyboard (inputmode="decimal"), and selects itself when tapped.
- Amount buttons are at least 44x44px with clear selected, focus and hover states. The selected state isn't shown by color alone: add a border, check or weight change too.

## 6. Copy
- **Headline:** what the gift does, in plain words, 4 to 10 words. The pattern is "[Verb] [specific outcome]", for example "Help families keep the lights on this winter." Avoid empty lines like "Make a difference today."
- **Supporting line:** one sentence with the who, what or why, ideally with one concrete, true detail.
- **Button:** a specific verb plus the amount when possible, for example "Give $50" or "Give $20 monthly". Not "Submit" or "Continue".
- **Tone:** warm, direct, grateful. Invite, don't pressure. No fake urgency, countdown timers, guilt, or "only X left".
- **Microcopy:** short reassurance under the button ("Secure payment. You'll get a receipt by email."), only claims that are true.
- **Thank-you state:** confirm the amount, say thanks in a human voice, say what happens next (the receipt), and offer one optional next step (share, or set up monthly). Not five.

## 7. Form and mobile-first
- Design at 375px first. Then check 320px, 390px, 768px and desktop.
- Ask only for what's required: amount, name, email, payment, and the address only if processing or compliance needs it. Every extra field costs gifts.
- Use Apple Pay and Google Pay when available, placed above the card fields.
- Every input has a visible label (not a placeholder alone), the right autocomplete attributes, and the right keyboard type.
- Show errors inline next to the field, in text and not just red color, and keep what the donor already typed.
- Tap targets at least 44x44px. A sticky give button on mobile only if it never covers fields and stays above the browser's toolbars.
- Keyboard and screen readers: logical tab order, a visible focus ring, the amount buttons work as a radio group, and errors are announced.
- Performance: aim for an interactive page in about 2 seconds on 4G. Avoid heavy scripts, autoplay video and pop-ups.
- Respect prefers-reduced-motion. Motion should be subtle (state changes), never decorative loops near the form.

## 8. Common mistakes to avoid
- A navigation menu, many links, or a newsletter pop-up on the donation page.
- A huge hero image that pushes the form below the fold on mobile.
- Too many amount options (7 or more), or the lowest one preselected.
- A monthly box pre-checked or hidden in fine print.
- Gray-on-gray text, a low-contrast button, or a light-on-light selected state.
- Text or logos baked into the header image.
- Long paragraphs above the form. Put the story below the form, or keep it to one line.
- Generic AI-looking design: purple gradients, emoji bullets, stacked shadowed cards, "Unlock / Empower / Seamless" headlines.
- Invented impact numbers, testimonials, partner logos or trust badges.
- Asking for a phone number, employer or anything else the gift doesn't need.

## 9. Final check before showing the user
- [ ] The headline and the first amounts are visible on a 375px screen without scrolling.
- [ ] One accent color, used only on the button and the selected states.
- [ ] Every text and UI pair passes WCAG 2.2 AA contrast.
- [ ] 3 to 5 amounts plus Other, a sensible preselect, and separate monthly tiers.
- [ ] The button says "Give $X". No pre-checked monthly box.
- [ ] Every claim, number and quote is real and from the org.
- [ ] The logo is in the header, and there's no text inside images.
- [ ] Fields are minimal, labeled and autofill-ready. Apple Pay and Google Pay if available.
- [ ] Checked at 320, 375, 768 and desktop, plus keyboard-only and reduced motion.
