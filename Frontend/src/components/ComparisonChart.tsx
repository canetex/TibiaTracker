import React from 'react';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend
} from 'recharts';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { formatNumber, formatDate } from '../lib/utils';

const colors = [
  "#1565C0", "#FFA726", "#4CAF50", "#F44336",
  "#9C27B0", "#FF5722", "#607D8B", "#795548"
];

interface ComparisonChartProps {
  characters: Array<{
    id: number;
    name: string;
  }>;
  data: Array<{
    date: string;
    [key: string]: any;
  }>;
}

const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload && payload.length) {
    return (
      <Card className="p-3 !bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <p className="text-sm font-medium">{formatDate(label)}</p>
        <div className="mt-2 space-y-1">
          {payload.map((entry: any, index: number) => (
            <p key={index} className="text-sm" style={{ color: entry.color }}>
              {entry.name}: {formatNumber(entry.value)}
            </p>
          ))}
        </div>
      </Card>
    );
  }
  return null;
};

export function ComparisonChart({ characters, data }: ComparisonChartProps) {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {characters.map((char, index) => (
          <Card key={char.id} className="p-4">
            <div className="flex items-center gap-2">
              <div
                className="w-3 h-3 rounded-full"
                style={{ backgroundColor: colors[index % colors.length] }}
              />
              <h4 className="font-medium">{char.name}</h4>
            </div>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Comparação de Experiência</CardTitle>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={400}>
            <AreaChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
              <defs>
                {characters.map((char, index) => (
                  <linearGradient
                    key={char.id}
                    id={`gradient-${char.id}`}
                    x1="0"
                    y1="0"
                    x2="0"
                    y2="1"
                  >
                    <stop
                      offset="5%"
                      stopColor={colors[index % colors.length]}
                      stopOpacity={0.8}
                    />
                    <stop
                      offset="95%"
                      stopColor={colors[index % colors.length]}
                      stopOpacity={0}
                    />
                  </linearGradient>
                ))}
              </defs>
              <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
              <XAxis
                dataKey="date"
                tickFormatter={formatDate}
                className="text-xs text-muted-foreground"
              />
              <YAxis
                tickFormatter={formatNumber}
                className="text-xs text-muted-foreground"
                yAxisId="left"
              />
              <YAxis
                tickFormatter={formatNumber}
                className="text-xs text-muted-foreground"
                yAxisId="right"
                orientation="right"
              />
              <Tooltip content={<CustomTooltip />} />
              <Legend />
              {characters.map((char, index) => (
                <Area
                  key={char.id}
                  type="monotone"
                  dataKey={`exp_${char.id}`}
                  name={char.name}
                  stroke={colors[index % colors.length]}
                  fill={`url(#gradient-${char.id})`}
                  stackId="1"
                  yAxisId="left"
                />
              ))}
            </AreaChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Comparação de Level</CardTitle>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={400}>
            <LineChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
              <XAxis
                dataKey="date"
                tickFormatter={formatDate}
                className="text-xs text-muted-foreground"
              />
              <YAxis
                tickFormatter={(value) => Math.floor(value)}
                className="text-xs text-muted-foreground"
                yAxisId="left"
              />
              <YAxis
                tickFormatter={(value) => `${Math.floor((value % 1) * 100)}%`}
                className="text-xs text-muted-foreground"
                yAxisId="right"
                orientation="right"
              />
              <Tooltip content={<CustomTooltip />} />
              <Legend />
              {characters.map((char, index) => (
                <Line
                  key={char.id}
                  type="stepAfter"
                  dataKey={`level_${char.id}`}
                  name={char.name}
                  stroke={colors[index % colors.length]}
                  strokeWidth={2}
                  strokeDasharray="5 5"
                  dot={{ fill: colors[index % colors.length], r: 4 }}
                  yAxisId="left"
                />
              ))}
            </LineChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    </div>
  );
} 