module WeatherHelper
  # Renders multi-tone inline SVG icons tailored for dark theme.
  # Icons supported: clear-day, clear-night, partly-cloudy-day, partly-cloudy-night, cloudy, fog, drizzle, rain, heavy-rain, sleet, snow, thunderstorm.
  def weather_icon_svg(icon_key, css_class: "w-12 h-12 flex-shrink-0")
    css_class = ERB::Util.html_escape(css_class)
    case icon_key.to_s
    when "clear-day"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <circle cx="32" cy="32" r="14" fill="#fbbf24" class="text-amber-400 drop-shadow-[0_0_8px_rgba(251,191,36,0.5)]" />
          <g stroke="#f59e0b" stroke-width="3" stroke-linecap="round">
            <line x1="32" y1="8" x2="32" y2="13" />
            <line x1="32" y1="51" x2="32" y2="56" />
            <line x1="8" y1="32" x2="13" y2="32" />
            <line x1="51" y1="32" x2="56" y2="32" />
            <line x1="15" y1="15" x2="19" y2="19" />
            <line x1="45" y1="45" x2="49" y2="49" />
            <line x1="15" y1="49" x2="19" y2="45" />
            <line x1="45" y1="19" x2="49" y2="15" />
          </g>
        </svg>
      SVG
    when "clear-night"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M40 14C27.85 14 18 23.85 18 36C18 48.15 27.85 58 40 58C45.3 58 50.15 56.12 54 52.95C40.6 51.5 30 40 30 26C30 21.3 31.45 16.95 34 13.35C35.95 13.78 37.95 14 40 14Z" fill="#818cf8" class="drop-shadow-[0_0_10px_rgba(129,140,248,0.4)]" />
          <circle cx="48" cy="18" r="1.5" fill="#c7d2fe" />
          <circle cx="54" cy="28" r="1" fill="#c7d2fe" />
        </svg>
      SVG
    when "partly-cloudy-day"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <!-- Sun in background -->
          <circle cx="26" cy="24" r="11" fill="#fbbf24" class="drop-shadow-[0_0_6px_rgba(251,191,36,0.45)]" />
          <g stroke="#f59e0b" stroke-width="2.5" stroke-linecap="round">
            <line x1="26" y1="6" x2="26" y2="10" />
            <line x1="8" y1="24" x2="12" y2="24" />
            <line x1="13" y1="11" x2="16" y2="14" />
            <line x1="39" y1="11" x2="36" y2="14" />
          </g>
          <!-- Cloud in foreground -->
          <path d="M22 50H46C51 50 55 46 55 41C55 36.3 51.5 32.5 47 32.1C46.5 24 40 18 32 18C25.3 18 19.7 22.3 17.8 28.5C13.4 29.2 10 33 10 37.5C10 42.5 14 50 22 50Z" fill="#94a3b8" />
          <path d="M22 48H46C50 48 53.5 44.8 53.5 41C53.5 37.2 50.5 34 46.8 33.8C46 26.5 40 20.5 32.5 20.5C26.5 20.5 21.2 24.5 19.5 30.2C15.5 30.8 12.5 34.2 12.5 38C12.5 42 15.5 48 22 48Z" fill="#cbd5e1" opacity="0.9" />
        </svg>
      SVG
    when "partly-cloudy-night"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <!-- Moon behind -->
          <path d="M30 14C23.5 14 18 19.5 18 26C18 32.5 23.5 38 30 38C32.8 38 35.4 37 37.4 35.3C30.2 34.5 24.5 28.5 24.5 21C24.5 18.5 25.3 16.1 26.6 14.2C27.7 14.4 28.8 14 30 14Z" fill="#818cf8" />
          <!-- Cloud in front -->
          <path d="M22 50H46C51 50 55 46 55 41C55 36.3 51.5 32.5 47 32.1C46.5 24 40 18 32 18C25.3 18 19.7 22.3 17.8 28.5C13.4 29.2 10 33 10 37.5C10 42.5 14 50 22 50Z" fill="#64748b" />
          <path d="M22 48H46C50 48 53.5 44.8 53.5 41C53.5 37.2 50.5 34 46.8 33.8C46 26.5 40 20.5 32.5 20.5C26.5 20.5 21.2 24.5 19.5 30.2C15.5 30.8 12.5 34.2 12.5 38C12.5 42 15.5 48 22 48Z" fill="#94a3b8" opacity="0.9" />
        </svg>
      SVG
    when "cloudy"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M28 20C21.4 20 16 25.4 16 32C16 32.7 16.1 33.3 16.2 34C13.8 35.3 12 37.9 12 41C12 45.4 15.6 49 20 49H44C49.5 49 54 44.5 54 39C54 33.8 50 29.5 45 29.1C44.4 24 40.1 20 34.8 20C32.4 20 30.2 20.8 28 22.2C28 21.5 28 20.8 28 20Z" fill="#64748b" />
          <path d="M21 47H45C49.4 47 53 43.4 53 39C53 34.8 49.8 31.4 45.7 31C45 24.4 39.5 19.3 32.7 19.3C26.7 19.3 21.6 23.3 20 29C15.6 29.6 12 33.4 12 38C12 43 16 47 21 47Z" fill="#94a3b8" />
        </svg>
      SVG
    when "fog"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M22 36H44C48 36 51 33 51 29C51 25.5 48.5 22.5 45 22.1C44 16 39 12 33 12C27.5 12 23 15.5 21.3 20.5C18 21 15 24 15 27.5C15 31.5 18 36 22 36Z" fill="#64748b" opacity="0.6" />
          <g stroke="#94a3b8" stroke-width="3" stroke-linecap="round">
            <line x1="14" y1="42" x2="50" y2="42" />
            <line x1="18" y1="48" x2="46" y2="48" />
            <line x1="22" y1="54" x2="42" y2="54" />
          </g>
        </svg>
      SVG
    when "drizzle"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M20 40H44C48.4 40 52 36.4 52 32C52 27.8 48.8 24.4 44.7 24C44 17.4 38.5 12.3 31.7 12.3C25.7 12.3 20.6 16.3 19 22C14.6 22.6 11 26.4 11 31C11 36 15 40 20 40Z" fill="#94a3b8" />
          <g stroke="#38bdf8" stroke-width="2" stroke-linecap="round">
            <line x1="22" y1="45" x2="20" y2="50" />
            <line x1="32" y1="45" x2="30" y2="50" />
            <line x1="42" y1="45" x2="40" y2="50" />
          </g>
        </svg>
      SVG
    when "rain"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M20 38H44C48.4 38 52 34.4 52 30C52 25.8 48.8 22.4 44.7 22C44 15.4 38.5 10.3 31.7 10.3C25.7 10.3 20.6 14.3 19 20C14.6 20.6 11 24.4 11 29C11 34 15 38 20 38Z" fill="#94a3b8" />
          <g stroke="#38bdf8" stroke-width="2.5" stroke-linecap="round">
            <line x1="21" y1="44" x2="18" y2="52" />
            <line x1="31" y1="44" x2="28" y2="52" />
            <line x1="41" y1="44" x2="38" y2="52" />
          </g>
        </svg>
      SVG
    when "heavy-rain"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M20 36H44C48.4 36 52 32.4 52 28C52 23.8 48.8 20.4 44.7 20C44 13.4 38.5 8.3 31.7 8.3C25.7 8.3 20.6 12.3 19 18C14.6 18.6 11 22.4 11 27C11 32 15 36 20 36Z" fill="#64748b" />
          <g stroke="#0284c7" stroke-width="3" stroke-linecap="round">
            <line x1="18" y1="42" x2="14" y2="53" />
            <line x1="28" y1="42" x2="24" y2="53" />
            <line x1="38" y1="42" x2="34" y2="53" />
            <line x1="48" y1="42" x2="44" y2="53" />
          </g>
        </svg>
      SVG
    when "sleet"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M20 36H44C48.4 36 52 32.4 52 28C52 23.8 48.8 20.4 44.7 20C44 13.4 38.5 8.3 31.7 8.3C25.7 8.3 20.6 12.3 19 18C14.6 18.6 11 22.4 11 27C11 32 15 36 20 36Z" fill="#94a3b8" />
          <g stroke="#38bdf8" stroke-width="2.5" stroke-linecap="round">
            <line x1="22" y1="43" x2="19" y2="51" />
            <line x1="42" y1="43" x2="39" y2="51" />
          </g>
          <circle cx="31" cy="46" r="2" fill="#e0f2fe" />
          <circle cx="33" cy="52" r="1.5" fill="#e0f2fe" />
        </svg>
      SVG
    when "snow"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M20 36H44C48.4 36 52 32.4 52 28C52 23.8 48.8 20.4 44.7 20C44 13.4 38.5 8.3 31.7 8.3C25.7 8.3 20.6 12.3 19 18C14.6 18.6 11 22.4 11 27C11 32 15 36 20 36Z" fill="#94a3b8" />
          <g stroke="#e0f2fe" stroke-width="2" stroke-linecap="round">
            <!-- snowflake 1 -->
            <line x1="22" y1="43" x2="22" y2="51" />
            <line x1="18" y1="47" x2="26" y2="47" />
            <!-- snowflake 2 -->
            <line x1="36" y1="43" x2="36" y2="51" />
            <line x1="32" y1="47" x2="40" y2="47" />
            <!-- snowflake 3 -->
            <line x1="48" y1="43" x2="48" y2="51" />
            <line x1="44" y1="47" x2="52" y2="47" />
          </g>
        </svg>
      SVG
    when "thunderstorm"
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M20 34H44C48.4 34 52 30.4 52 26C52 21.8 48.8 18.4 44.7 18C44 11.4 38.5 6.3 31.7 6.3C25.7 6.3 20.6 10.3 19 16C14.6 16.6 11 20.4 11 25C11 30 15 34 20 34Z" fill="#475569" />
          <!-- Lightning bolt -->
          <polygon points="34,32 25,44 32,44 28,58 41,42 33,42" fill="#fbbf24" class="drop-shadow-[0_0_8px_rgba(251,191,36,0.6)]" />
        </svg>
      SVG
    else
      # Fallback sun/cloud
      <<-SVG.html_safe
        <svg class="#{css_class}" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <circle cx="26" cy="24" r="11" fill="#fbbf24" />
          <path d="M22 48H46C50 48 53.5 44.8 53.5 41C53.5 37.2 50.5 34 46.8 33.8C46 26.5 40 20.5 32.5 20.5C26.5 20.5 21.2 24.5 19.5 30.2C15.5 30.8 12.5 34.2 12.5 38C12.5 42 15.5 48 22 48Z" fill="#cbd5e1" />
        </svg>
      SVG
    end
  end
end
