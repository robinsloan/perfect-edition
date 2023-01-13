# Note that this script doesn't handle CSS comments very well!
# It can capture comments of the kind
# font-size: 100px; /* because it's gotta be BIG */
# but not
# /* Because it's gotta be BIG: */
# font-size: 100px
# because it has no concept of a multi-line "bundle".

RULE_ORDER = %w(
position
display
flex-direction
flex-wrap
flex-basis flex-grow flex-shrink
align-items
align-self
justify-content
gap

grid-template-columns
grid-column

columns
column-gap
column-fill
column-count
column-width

break-before
break-after
break-inside
page-break-after

top
right
bottom
left

touch-action
scroll-behavior
pointer-events
cursor

content

width min-width max-width
height min-height max-height
transform

overflow overflow-x overflow-y

margin margin-top margin-right margin-bottom margin-left
padding padding-top padding-right padding-bottom padding-left

-webkit-appearance
background
background-color background-image
background-size background-position
background-repeat
border border-top border-right border-bottom border-left
border-radius
border-top-right-radius border-bottom-right-radius
border-bottom-left-radius border-top-left-radius
outline
box-shadow
fill
stroke
stroke-width
opacity

list-style-type

animation
transition
mix-blend-mode
object-fit

font-family
font-size
font-style
font-weight
font-feature-settings
font-variant
font-variant-caps
hyphens
hyphenate-limit-last

letter-spacing
line-height

text-align
text-indent
text-rendering
text-transform
text-decoration
text-decoration-color
text-decoration-thickness
text-underline-offset
text-shadow
white-space


color

z-index
)

puts RULE_ORDER

$infile = File.open("source/css/web.css")
$outfile = File.open("sorted.css", "w")

$current_selector = ""
$current_rules = []

$missed_rules = {}

def sort_and_output_current_rules
  $outfile.puts $current_selector

  sortable_rules = []

  $current_rules.each do |rule|
    if rule.match(/^\s*\/\*/)
      next
    end

    if rule.match(/^\s*--/)
      $outfile.puts rule
      next
    end

    if rule.length <= 1
      next
    end

    rule_name = rule.split(":").first.strip
    rule_order = RULE_ORDER.index(rule_name) || 10000
    sortable_rules << {"text" => rule, "order" => rule_order}
  end

  sortable_rules = sortable_rules.sort_by do |rule|
    rule["order"]
  end

  sortable_rules.each do |rule|
    $outfile.puts rule["text"]
  end
end

capturing_rules = false

$infile.each_line do |line|
  if line.match(/\{$/)
    unless line.match(/^\s*@/)
      $current_selector = line
      $current_rules = []
      capturing_rules = true
      next
    end
  end

  if capturing_rules && line.match(/\}$/)
    sort_and_output_current_rules
    capturing_rules = false
  end

  if capturing_rules
    $current_rules << line
  else
    $outfile.puts line
  end
end

$outfile.close