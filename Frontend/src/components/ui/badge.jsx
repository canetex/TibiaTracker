import * as React from "react"
import { cva } from "class-variance-authority"

import { cn } from "../../lib/utils"

const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default:
          "border-transparent bg-primary text-primary-foreground hover:bg-primary/80",
        secondary:
          "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80",
        destructive:
          "border-transparent bg-destructive text-destructive-foreground hover:bg-destructive/80",
        outline: "text-foreground",
        success:
          "border-transparent bg-tibia-green text-white hover:bg-tibia-green/80",
        warning:
          "border-transparent bg-yellow-500 text-white hover:bg-yellow-500/80",
        sorcerer:
          "border-transparent bg-sorcerer text-white hover:bg-sorcerer/80",
        druid:
          "border-transparent bg-druid text-white hover:bg-druid/80",
        paladin:
          "border-transparent bg-paladin text-white hover:bg-paladin/80",
        knight:
          "border-transparent bg-knight text-white hover:bg-knight/80",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

function Badge({ className, variant, ...props }) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  )
}

export { Badge, badgeVariants }