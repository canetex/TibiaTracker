import React from 'react'

export default function Spinner({ size = 32 }: { size?: number }): JSX.Element {
  return (
    <div
      className="animate-spin rounded-full border-b-2 border-primary opacity-80"
      style={{ width: size, height: size }}
    />
  )
}
